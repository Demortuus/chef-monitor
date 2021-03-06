#
# Cookbook Name:: monitor
# Recipe:: _extension_nagios_perfdata
#
# Copyright 2013, Sean Porter Consulting
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

include_recipe 'monitor::_extensions'

cookbook_file File.join(node['monitor']['server_extension_dir'], 'nagios_perfdata.rb') do
  source 'extensions/nagios_perfdata.rb'
  mode 0o755
  notifies :create, 'ruby_block[sensu_service_trigger]', :immediately
end
