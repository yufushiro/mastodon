# frozen_string_literal: true

class Webhooks::MisskeyReactionEvent < ActiveModelSerializers::Model
  attributes :uri, :acct, :emoji, :emoji_url, :created_at
end
