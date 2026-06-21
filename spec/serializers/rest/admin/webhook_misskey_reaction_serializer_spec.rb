# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::Admin::WebhookMisskeyReactionSerializer do
  subject do
    serialized_record_json(event, described_class)
  end

  let!(:emoji) do
    stub_request(:get, "https://example.com/eyes.png").to_return(
      status: 200,
      body: ""
    )
    Fabricate(
      :custom_emoji,
      domain: 'example.com',
      shortcode: 'eyes',
      image_remote_url: 'https://example.com/eyes.png'
    )
  end

  context 'when emoji_url is present on the event' do
    let!(:event) do
      Webhooks::MisskeyReactionEvent.new(
        uri: 'https://example.com/@alice/1',
        acct: 'hoge@example.com',
        emoji: ':eyes:',
        emoji_url: 'https://example.com/eyes-custom.png',
        created_at: Time.zone.now,
      )
    end

    it 'serializes the explicit URL from the incoming payload' do
      expect(subject).to eq(
        'uri' => 'https://example.com/@alice/1',
        'acct' => 'hoge@example.com',
        'emoji' => ':eyes:',
        'emoji_url' => 'https://example.com/eyes-custom.png',
        'created_at' => event.created_at.as_json
      )
    end
  end

  context 'when emoji_url is absent on the event' do
    let!(:event) do
      Webhooks::MisskeyReactionEvent.new(
        uri: 'https://example.com/@alice/1',
        acct: 'hoge@example.com',
        emoji: ':eyes:',
        created_at: Time.zone.now,
      )
    end

    it 'falls back to the custom emoji URL resolved from the database' do
      expect(subject).to eq(
        'uri' => 'https://example.com/@alice/1',
        'acct' => 'hoge@example.com',
        'emoji' => ':eyes:',
        'emoji_url' => 'https://example.com/eyes.png',
        'created_at' => event.created_at.as_json
      )
    end
  end
end
