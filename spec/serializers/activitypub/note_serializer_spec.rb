# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::NoteSerializer do
  subject { serialized_record_json(parent, described_class, adapter: ActivityPub::Adapter) }

  let!(:account) { Fabricate(:account) }
  let!(:other) { Fabricate(:account) }
  let!(:parent) { Fabricate(:status, account: account, visibility: :public, language: 'zh-TW') }
  let!(:reply_by_account_first) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_next) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_other_first) { Fabricate(:status, account: other, thread: parent, visibility: :public) }
  let!(:reply_by_account_third) { Fabricate(:status, account: account, thread: parent, visibility: :public) }
  let!(:reply_by_account_visibility_direct) { Fabricate(:status, account: account, thread: parent, visibility: :direct) }

  it 'has the expected shape and replies collection' do
    expect(subject).to include({
      '@context' => include('https://www.w3.org/ns/activitystreams'),
      'type' => 'Note',
      'attributedTo' => ActivityPub::TagManager.instance.uri_for(account),
      'contentMap' => include({
        'zh-TW' => a_kind_of(String),
      }),
      'replies' => replies_collection_values,
      'context' => ActivityPub::TagManager.instance.uri_for(parent.conversation),
    })
  end

  def replies_collection_values
    include(
      'type' => eql('Collection'),
      'first' => include(
        'type' => eql('CollectionPage'),
        'items' => reply_items
      )
    )
  end

  def reply_items
    include(reply_by_account_first.uri, reply_by_account_next.uri, reply_by_account_third.uri) # Public self replies
      .and(not_include(reply_by_other_first.uri)) # Replies from others
      .and(not_include(reply_by_account_visibility_direct.uri)) # Replies with direct visibility
  end

  context 'with tagged featured collections' do
    let(:collection) { Fabricate(:collection) }

    before do
      parent.tagged_objects.create!(object: collection, ap_type: 'FeaturedCollection', uri: ActivityPub::TagManager.instance.uri_for(collection))
    end

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'tag' => include(
          a_hash_including({
            'type' => 'FeaturedCollection',
            'id' => ActivityPub::TagManager.instance.uri_for(collection),
          })
        ),
      })
    end
  end

  context 'with a quote' do
    let(:quoted_status) { Fabricate(:status) }
    let!(:quote) { Fabricate(:quote, status: parent, quoted_status: quoted_status, state: :accepted) }

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        'quoteUri' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        '_misskey_quote' => ActivityPub::TagManager.instance.uri_for(quote.quoted_status),
        'quoteAuthorization' => ActivityPub::TagManager.instance.approval_uri_for(quote),
      })
    end
  end

  context 'with a deleted quote' do
    let(:quoted_status) { Fabricate(:status) }

    before do
      Fabricate(:quote, status: parent, quoted_status: nil, state: :accepted)
    end

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'quote' => { 'type' => 'Tombstone' },
      })
    end
  end

  context 'with a quote policy' do
    let(:parent) { Fabricate(:status, quote_approval_policy: InteractionPolicy::POLICY_FLAGS[:followers] << 16) }

    it 'has the expected shape' do
      expect(subject).to include({
        'type' => 'Note',
        'interactionPolicy' => a_hash_including(
          'canQuote' => a_hash_including(
            'automaticApproval' => [ActivityPub::TagManager.instance.followers_uri_for(parent.account)]
          )
        ),
      })
    end
  end

  context 'with a preview card' do
    let(:preview_card) { Fabricate(:preview_card) }

    before do
      PreviewCardsStatus.create(status: parent, preview_card: preview_card)
    end

    it 'has the expected shape (using FEP-8967)' do
      expect(subject).to include({
        'type' => 'Note',
        'attachment' => contain_exactly(
          a_hash_including(
            'href' => preview_card.url
          )
        ),
      })
    end
  end

  # m.yufushiro.dev 用の拡張 (Misskey 互換の引用機能)
  describe '[yufushiro]' do
    context 'with legacy quote' do
      subject { serialized_record_json(quote_status, described_class, adapter: ActivityPub::Adapter) }

      let!(:quote_status) do
        Fabricate(
          :status,
          text: <<~TEXT
            hogehoge

            RE: https://example.com/statuses/1234
          TEXT
        )
      end

      it 'has the expected shape for legacy quote status' do
        expect(subject).to include({
          '@context' => [
            'https://www.w3.org/ns/activitystreams',
            include(
              '_misskey_quote' => 'https://misskey-hub.net/ns#_misskey_quote'
            ),
          ],
          'type' => 'Note',
          'content' =>
            '<p>hogehoge</p>' \
            '<p class="quote-inline">RE: ' \
            '<a href="https://example.com/statuses/1234" target="_blank" rel="nofollow noopener" translate="no">' \
            '<span class="invisible">https://</span>' \
            '<span class="">example.com/statuses/1234</span>' \
            '<span class="invisible"></span>' \
            '</a>' \
            '</p>',
          'source' => {
            'mediaType' => 'text/x.misskeymarkdown',
            'content' => 'hogehoge',
          },
          '_misskey_quote' => 'https://example.com/statuses/1234',
        })
        expect(subject).not_to include('quote')
      end
    end

    # v4.5.x の引用機能 + Misskey 向け出力
    context 'with quote' do
      subject { serialized_record_json(quote_status, described_class, adapter: ActivityPub::Adapter) }

      let(:remote_account) { Fabricate(:account, domain: 'example.com') }
      let(:quoted_status) { Fabricate(:status, account: remote_account, uri: 'https://example.com/statuses/1234') }
      let(:quote_status) { Fabricate(:status, text: 'hogehoge') }
      let!(:quote) do
        Fabricate(
          :quote,
          status: quote_status,
          quoted_status: quoted_status,
          state: :accepted
        )
      end

      it 'has the expected shape for quote status' do
        expect(subject).to include({
          '@context' => [
            'https://www.w3.org/ns/activitystreams',
            include(
              '_misskey_quote' => 'https://misskey-hub.net/ns#_misskey_quote'
            ),
          ],
          'type' => 'Note',
          'content' =>
            '<p class="quote-inline">RE: ' \
            '<a href="https://example.com/statuses/1234" target="_blank" rel="nofollow noopener" translate="no">' \
            '<span class="invisible">https://</span>' \
            '<span class="">example.com/statuses/1234</span>' \
            '<span class="invisible"></span>' \
            '</a>' \
            '</p>' \
            '<p>hogehoge</p>',
          'source' => {
            'mediaType' => 'text/x.misskeymarkdown',
            'content' => 'hogehoge',
          },
          'quote' => 'https://example.com/statuses/1234',
          '_misskey_quote' => 'https://example.com/statuses/1234',
        })
      end
    end
  end
end
