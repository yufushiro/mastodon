# frozen_string_literal: true

class ServerExploreController < ApplicationController
  skip_before_action :require_functional!

  def show
    hidden_domains = %w[
      mastodon.cloud
      matitodon.com
      mi.yufushiro.dev
      mozilla.social
    ]

    @servers = Account.remote
      .joins(:passive_relationships)
      .where(follows: { account: Account.local })
      .where.not(domain: hidden_domains)
      .group(:domain)
      .order(Arel.sql('COUNT(*) DESC'))
      .limit(20)
      .pluck(:domain, Arel.sql('COUNT(*)'))

    @server_descriptions = {
      'misskey.io' => '株式会社MisskeyHQが運営する地球で生まれた分散マイクロブログSNSです',
      'mstdn.jp' => 'Mastodon日本鯖です',
      'onsen-musume.fun' => 'ふろがすきなおたくのあつまりを掲げるMisskeyサーバー',
      'social.mikutter.hachune.net' => '雑談用です。mikutterに関係しないことを話しても構いません',
      'pawoo.net' => '創作活動や自由なコミュニケーションを楽しめる場',
      'mastodon.social' => 'Mastodon GmbH が運営するMastodonの公式サーバー',
      'threads.net' => 'Meta社が運営するInstagramのアカウントで登録できるサーバー',
      'fedibird.com' => '様々な目的に使える、日本の汎用マストドンサーバーです',
      'fosstodon.org' => 'FOSSに関心のあるコミュニティ向けのサーバー',
      'mstdn.maud.io' => '秘密結社あかねぶるーが運用する日本語を主とした汎用Mastodonサーバー',
      'ruby.social' => 'Ruby関連のトピックに関心のある人向けのサーバー',
    }

    expires_in(10.minutes, public: true, stale_while_revalidate: 1.hour, stale_if_error: 1.day) unless user_signed_in?
  end
end
