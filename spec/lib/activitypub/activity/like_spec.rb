# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityPub::Activity::Like do
  let(:sender)    { Fabricate(:account, domain: 'example.com') }
  let(:recipient) { Fabricate(:account) }
  let(:status)    { Fabricate(:status, account: recipient) }

  let(:json) do
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: 'foo',
      type: 'Like',
      actor: ActivityPub::TagManager.instance.uri_for(sender),
      object: ActivityPub::TagManager.instance.uri_for(status),
    }.with_indifferent_access
  end

  describe '#perform' do
    subject { described_class.new(json, sender) }

    before do
      subject.perform
    end

    it 'creates a favourite from sender to status' do
      expect(sender.favourited?(status)).to be true
    end
  end

  describe '[yufushiro] #perform with Misskey reaction' do
    it 'sends a custom webhook event when the payload includes _misskey_reaction' do
      service = instance_double(WebhookService)
      allow(WebhookService).to receive(:new).and_return(service)
      allow(service).to receive(:call)

      reaction_activity = described_class.new(json.merge('_misskey_reaction' => '👀'), sender)
      reaction_activity.perform

      expect(service).to have_received(:call) do |event, payload|
        expect(event).to eq('status.misskey_reaction')
        expect(payload).to be_a(Webhooks::MisskeyReactionEvent)
        expect(payload.uri).to eq(status.uri)
        expect(payload.acct).to eq(sender.acct)
        expect(payload.emoji).to eq('👀')
        expect(payload.created_at).to be_within(5.seconds).of(Time.zone.now)
      end
    end
  end
end
