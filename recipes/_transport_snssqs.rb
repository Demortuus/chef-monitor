#
# Cookbook Name:: monitor
# Recipe:: _transport_snssqs
#
# Copyright 2016, Philipp H
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

node.set['sensu']['use_ssl'] = false

sensu_gem 'aws-sdk' do
end

# https://github.com/SimpleFinance/sensu-transport-snssqs
# sensu_gem 'sensu-transport-snssqs' do
#  action :install
# end

cookbook_file '/opt/sensu/embedded/lib/ruby/gems/2.3.0/gems/sensu-transport-6.0.0/lib/sensu/transport/snssqs.rb' do
  source 'transports/snssqs.rb'
  owner 'root'
  group 'root'
  mode 00644
end

if node.key?('ec2') && node['ec2'].key?('placement_availability_zone')
  region = node['ec2']['placement_availability_zone'].scan(/[a-z]+\-[a-z]+\-[0-9]+/)
  if region.count > 0 && node['monitor']['snsqs_region'].nil?
    node.set['monitor']['snssqs_region'] = region.first
  end
end

sensu_snippet 'snssqs' do
  content(
    max_number_of_messages: node['monitor']['snssqs_max_number_of_messages'],
    wait_time_seconds: node['monitor']['snssqs_wait_time_seconds'],
    region: node['monitor']['snssqs_region'],
    consuming_sqs_queue_url: node['monitor']['snssqs_consuming_sqs_queue_url'],
    publishing_sns_topic_arn: node['monitor']['snssqs_publishing_sns_topic_arn'],
    statsd_addr: node['monitor']['snssqs_statsd_addr'],
    statsd_namespace: node['monitor']['snssqs_statsd_namespace'],
    statsd_sample_rate: node['monitor']['snssqs_statsd_sample_rate']
  )
end

# {
#  "snssqs": {
#    "max_number_of_messages": 10,
#    "wait_time_seconds": 2,
#    "region": "{{ AWS_REGION }}",
#    "consuming_sqs_queue_url": "{{ SENSU_QUEUE_URL }}",
#    "publishing_sns_topic_arn": "{{ SENSU_SNS_ARN }}"
#    },
# }