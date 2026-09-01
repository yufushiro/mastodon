# frozen_string_literal: true

class ActivityPub::Activity::Delete < ActivityPub::Activity
  def perform
    return delete_person if @account.uri == object_uri
    return delete_feature_authorization! unless feature_authorization_from_object.nil?

    delete_object
  end

  private

  def delete_person
    # Workaround for some implementations (such as Misskey) that send Delete activity for non-permanent account suspension.
    @account.silence!
    admin_account = Account.local.find_by(username: 'yufushiro')
    if admin_account.present?
      AccountModerationNote.create!(
        account: admin_account,
        target_account: @account,
        content: 'Delete activity has been received.'
      )
    end
  end

  def delete_object
    return if object_uri.nil?

    with_redis_lock("delete_status_in_progress:#{object_uri}", raise_on_failure: false) do
      unless non_matching_uri_hosts?(@account.uri, object_uri)
        # This lock ensures a concurrent `ActivityPub::Activity::Create` either
        # does not create a status at all, or has finished saving it to the
        # database before we try to load it.
        # Without the lock, `delete_later!` could be called after `delete_arrived_first?`
        # and `Status.find` before `Status.create!`
        with_redis_lock("create:#{object_uri}") { delete_later!(object_uri) }

        Tombstone.find_or_create_by(uri: object_uri, account: @account)
      end

      case @object['type']
      when 'QuoteAuthorization'
        revoke_quote
      when 'Note', 'Question'
        delete_status
      else
        delete_status || revoke_quote
      end
    end
  end

  def delete_status
    @status   = Status.find_by(uri: object_uri, account: @account)
    @status ||= Status.find_by(uri: @object['atomUri'], account: @account) if @object.is_a?(Hash) && @object['atomUri'].present?

    return if @status.nil?

    if @status.has_favourite_or_bookmarked?
      @status.update! visibility: :private
      @status.reblogs.update_all visibility: :private
      return
    end

    forwarder.forward! if forwarder.forwardable?
    RemoveStatusService.new.call(@status, redraft: false)

    true
  end

  def revoke_quote
    @quote = Quote.find_by(approval_uri: object_uri, quoted_account: @account, state: [:pending, :accepted])
    return if @quote.nil?

    ActivityPub::Forwarder.new(@account, @json, @quote.status).forward! if @quote.status.present?

    @quote.reject!

    DistributionWorker.perform_async(@quote.status_id, { 'update' => true }) if @quote.status.present?
  end

  def delete_feature_authorization!
    collection_item = feature_authorization_from_object
    DeleteCollectionItemService.new.call(collection_item, revoke: true)
  end

  def forwarder
    @forwarder ||= ActivityPub::Forwarder.new(@account, @json, @status)
  end

  def feature_authorization_from_object
    return @collection_item if instance_variable_defined?(:@collection_item)

    @collection_item = CollectionItem.local.find_by(approval_uri: value_or_id(@object), account_id: @account.id)
  end
end
