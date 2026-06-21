# frozen_string_literal: true

class Webhooks::MisskeyReactionEvent < ActiveModelSerializers::Model
  attributes :uri, :acct, :emoji, :created_at
end
