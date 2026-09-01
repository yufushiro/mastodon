# frozen_string_literal: true

class REST::Admin::WebhookMisskeyReactionSerializer < ActiveModel::Serializer
  attributes :uri, :acct, :emoji, :emoji_url, :created_at

  def emoji_url
    domain = object.acct.split('@').last
    resolved_emojis = CustomEmoji.from_text(object.emoji, domain)
    resolved_emojis.map(&:image_remote_url).first
  end
end
