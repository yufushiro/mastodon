# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::Admin::WebhookMisskeyReactionSerializer do
  subject do
    serialized_record_json(event, described_class)
  end

  let!(:event) do
    Webhooks::MisskeyReactionEvent.new(
      uri: 'https://example.com/@alice/1',
      acct: 'hoge@example.com',
      emoji: ':eyes:',
      created_at: Time.zone.now,
    )
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

  it 'serializes the event' do
    expect(subject).to eq(
      'uri' => 'https://example.com/@alice/1',
      'acct' => 'hoge@example.com',
      'emoji' => ':eyes:',
      'emoji_url' => 'https://example.com/eyes.png',
      'created_at' => event.created_at.as_json
    )
  end
end
