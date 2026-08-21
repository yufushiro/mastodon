# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Server explore' do
  describe 'GET /server_explore' do
    let!(:local_account) { Fabricate(:account, domain: nil) }
    let!(:other_local_account) { Fabricate(:account, domain: nil) }
    let!(:first_remote_account) { Fabricate(:account, domain: 'first.example') }
    let!(:second_remote_account) { Fabricate(:account, domain: 'second.example') }

    before do
      local_account.follow!(first_remote_account)
      other_local_account.follow!(first_remote_account)
      local_account.follow!(second_remote_account)
    end

    it 'shows remote servers ordered by the number of local follows' do
      get '/server_explore'

      expect(response).to have_http_status(200)
      expect(response.body.index('first.example')).to be < response.body.index('second.example')
      expect(response.body).to include('first.example', '2', 'second.example', '1')
    end
  end
end
