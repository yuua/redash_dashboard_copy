#!/usr/bin/env ruby

require 'bundler/setup'
require 'dotenv'
require 'active_record'
require 'net/ssh/gateway'
Dotenv.load

config = YAML.load_file( './config/database.yml' )

gateway = Net::SSH::Gateway.new(
  config['db'][ENV['environment']]['gateway_host'],
  'ec2-user',
  keys: config['db'][ENV['environment']]['gateway_key']
)

port = gateway.open(config['db'][ENV['environment']]['redash_db_host'],5432)

ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: 'localhost',
  username: config['db'][ENV['environment']]['username'],
  port: port,
  password: config['db'][ENV['environment']]['password'],
  database: 'redash'
)

class Visualization < ActiveRecord::Base
  self.inheritance_column = :_type_disabled
  belongs_to :query
  has_one :widget

  validates :name, presence: true
  
end

class User < ActiveRecord::Base
  has_many :queries
end

class Dashboard < ActiveRecord::Base
  scope :slug_in , -> (slug) {where("slug = ?", slug)}

  def self.save_dashboard(dashboard_data,widget_data)
    ActiveRecord::Base.transaction do
      dashboard = Dashboard.transaction do
        dashboard = Dashboard.create!(dashboard_data)
      end
      Widget.transaction do
        widget_data.each do |values|
          values.store(:dashboard_id,dashboard.id)
          Widget.create!(values)
        end
      end
      puts "ダッシュボードID: #{dashboard.id}をCopyしました"
      puts "#{ENV['REDASH_ENDPOINT']}dashboard/#{dashboard.slug}"
    end
  rescue ActiveRecord::RecordInvalid
    ActiveRecord::Rollback
    raise
  end
end

class Query < ActiveRecord::Base
  belongs_to :user
  has_many :visualizations
end

class Widget < ActiveRecord::Base
  belongs_to :visualization

end

