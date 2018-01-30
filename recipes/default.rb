#
# Cookbook Name:: statsd
# Recipe:: default
#
# Copyright 2011, Blank Pad Development
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



include_recipe "nodejs"

statsd_version = node['statsd']['sha']


if platform?(%w{ debian })

  include_recipe "build-essential"
  include_recipe "git"

  git "#{node[:statsd][:tmp_dir]}/statsd" do
    repository node[:statsd][:repo]
    reference statsd_version
    action :sync
    notifies :run, "execute[build debian package]"
  end

  package "debhelper"

  # Fix the debian changelog file of the repo
  template "#{node[:statsd][:tmp_dir]}/statsd/debian/changelog" do
    source "changelog.erb"
  end

  execute "build debian package" do
    command "dpkg-buildpackage -us -uc"
    cwd "#{node[:statsd][:tmp_dir]}/statsd"
    creates "#{node[:statsd][:tmp_dir]}/statsd_#{node[:statsd][:package_version]}_all.deb"
  end

  dpkg_package "statsd" do
    action :install
    source "#{node[:statsd][:tmp_dir]}/statsd_#{node[:statsd][:package_version]}_all.deb"
  end
end

if platform?(%w{ redhat centos fedora })

#  chef_gem 'fpm'
  gem_package "fpm" do
	  gem_binary "/opt/chef/embedded/bin/gem"
	    action :nothing
  end.run_action(:install)

  Gem.clear_paths

  directory "/etc/statsd/git" do
    recursive true
  end

  directory "/usr/share/statsd/scripts" do
    recursive true
  end

  include_recipe 'git'

  git '/etc/statsd/git' do
    repository 'https://github.com/etsy/statsd.git'
    reference 'v0.6.0'
    action :sync
  end
end

template "/etc/statsd/rdioConfig.js" do
  source "rdioConfig.js.erb"
  mode 0644
  variables(
    :port => node[:statsd][:port],
    :graphitePort => node[:statsd][:graphite_port],
    :graphiteHost => node[:statsd][:graphite_host]
  )

  notifies :restart, "service[statsd]"
end

user node[:statsd][:user] do
  comment "statsd"
  system true
  shell "/bin/false"
  home "/var/log/statsd"
end

case node['platform']
when 'ubuntu'
  cookbook_file "/etc/init/statsd.conf" do
    source "upstart.conf"
    mode 0644
  end

  cookbook_file "/usr/share/statsd/scripts/start" do
    source "upstart.start"
    mode 0755
  end

  service "statsd" do
    provider Chef::Provider::Service::Upstart
    action [ :enable, :start ]
  end
when 'centos'
  cookbook_file "/etc/systemd/system/statsd.service" do
    source "statsd.service.erb"
    mode 0644
  end

  cookbook_file "/usr/share/statsd/scripts/start" do
    source "statsd_service.start"
    mode 0755
  end

  service 'statsd' do
    provider Chef::Provider::Service::Systemd
    action [ :enable, :start ]
  end
end
