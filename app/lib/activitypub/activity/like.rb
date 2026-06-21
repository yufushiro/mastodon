# frozen_string_literal: true

class ActivityPub::Activity::Like < ActivityPub::Activity
  def perform
    original_status = status_from_uri(object_uri)

    return if original_status.nil? || !original_status.account.local? || delete_arrived_first?(@json['id']) || @account.favourited?(original_status)

    favourite = original_status.favourites.create!(account: @account)

    LocalNotificationWorker.perform_async(original_status.account_id, favourite.id, 'Favourite', 'favourite')
    Trends.statuses.register(original_status)

    if @json['_misskey_reaction'].present?
      WebhookService.new.call(
        'status.misskey_reaction',
        Webhooks::MisskeyReactionEvent.new(
          uri: original_status.uri,
          acct: @account.acct,
          emoji: @json['_misskey_reaction'],
          emoji_url: extract_emoji_url(@json['_misskey_reaction']),
          created_at: Time.zone.now,
        )
      )
    end
  end

  private

  def extract_emoji_url(name)
    tags = @json['tag']
    return nil unless tags.is_a?(Array)

    found_tag = tags.find do |tag|
      tag.is_a?(Hash) && tag['type'] == 'Emoji' && tag['name'] == name
    end

    found_tag&.dig('icon', 'url')
  end
end
