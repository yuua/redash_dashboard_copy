#!/usr/bin/env ruby

require 'bundler/setup'
require 'dotenv'
require './models'
require 'faraday'
require 'optparse'
require 'json'
require 'date'
require 'socket'
require "digest/md5"

Dotenv.load

class Copy
  attr_accessor :dashboard_slug,:query_copy
  REDASH_ENDPOINT = ENV['REDASH_ENDPOINT']

  def initialize
    @query_copy = true
    option = OptionParser.new
    option.on('-d,--dashboard_slug','dashboard slug') {|v| @dashboard_slug = v}
    option.on('-q', '--[no-]query', "boolean value") {|v| @query_copy = v}
    option.parse!(ARGV)
  end

  def find_dashboard(slug)
    res = Faraday.get "#{REDASH_ENDPOINT}api/dashboards/#{slug}?api_key=#{ENV["REDASH_API_KEY"]}"
    unless res.success?
      puts "#{slug}は不正な値です"
      return false
    end
    JSON.parse(res.body)
  end

  def slugify(s)
    s.gsub(/[^a-z0-9_\-]+/,'-').downcase
  end

  def generate_slug(name)
    tmp_slug = Digest::MD5.hexdigest(Socket.gethostname)[0..4] +  slugify(name)
    loop do
      data = Dashboard.slug_in(tmp_slug).first
      break if data.nil?
      tmp_slug = tmp_slug + Time.now.to_i.to_s
    end
    tmp_slug
  end

  def copy_dashboard(d)
    {
      is_archived: d['is_archived'],
      layout: "[]",
      is_draft: true,
      slug: generate_slug(d['name']),
      dashboard_filters_enabled: d['dashboard_filters_enabled'],
      name: "【Copy #{d['id']}】#{d['name']}",
      org_id: 1,
      version: 1
    }
  end

  def copy_widget(d,id)
    {
      text: d['text'],
      width: d['width'],
      options: d['options'].to_json,
      visualization_id: id
    }
  end

  # visualizationもforkされる
  def copy_query(d)
    res = Faraday.post do |req|
      req.url "#{REDASH_ENDPOINT}api/queries/#{d["id"]}/fork"
      req.headers['Authorization'] = ENV["REDASH_API_KEY"]
    end
    unless res.success?
      puts "クエリのforkに失敗しました"
      return false
    end
    JSON.parse(res.body)
  end

  def find_visual_data(before,after)
    result = after.find do |value|
      value['name'] == before['name'] && value['type'] == before['type'] && value['description'] == before['description'] && value['option'] == before['option']
    end
    result['id']
  end

  def main(slugs)
    query_ids = {}
    user_id = nil
    new_query_id = []
    slugs.each do |slug|
      widget_item = [] # slugのたびに初期化
      dashboard = find_dashboard(slug)
      # copyするダッシュボード
      dashboard_item = copy_dashboard(dashboard)
      dashboard['widgets'].each do |widget|
        # copyするwidget
        visualization = widget['visualization']
        if visualization.present?
            # 前のデータを検索するためidだけ確保
          visual_id = visualization["id"]
          query = visualization['query']
          unless query_ids.key?(query['id'].to_s) 
            res = if @query_copy
              result = copy_query(query)
              unless result
                puts "処理を停止します"
                raise "error"
              end
              result
            else 
              query
            end
            user_id = res["user"]["id"]
            #TODO: 新しいquery idの一覧エラー時にarchive化するようにする
            new_query_id.push(res["id"])
            # queryに紐づくvisualizationを保持
            query_ids.store(query['id'].to_s,res['visualizations'])
          end
          # sqlでとる
          id = if @query_copy
                find_visual_data(Visualization.find(visual_id),query_ids[query['id'].to_s])
               else 
                visual_id
               end
          widget_item.push(copy_widget(widget,id))
        else
          widget_item.push(copy_widget(widget,nil))
        end
        dashboard_item[:user_id] = user_id
      end
      begin
        puts dashboard_item
        Dashboard.save_dashboard(dashboard_item,widget_item)
      rescue
        # archive化する
        puts "エラーが発生したため、作成したQueryとDashboardをarchive化しました"
        puts "query id #{new_query_id}"
        puts "dashboard slug #{dashboard_item[:slug]}"
        Query.where(id: new_query_id).update_all(is_archived: true)
        Dashboard.find_by(slug: dashboard_item[:slug]).update(is_archived: true)
      end
    end
  end
end

a = Copy.new
a.main(a.dashboard_slug.split(","))
