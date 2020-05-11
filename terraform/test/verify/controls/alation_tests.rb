title 'alation terraform tests'

# load data from terraform output
content = inspec.profile.file("terraform.json")
params = JSON.parse(content)

HAPROXY_LB_IP = params['haproxy-ip']['value']

# execute test

# describe aws_ec2_instances do
#     its('entries.count') { should eq 3}
# end

describe aws_ec2_instances.where(tags: {"Name" => "alation-lb"}) do
    it { should exist }
    its('entries.count') {should eq 1}
end

describe aws_ec2_instance(name: 'alation-lb') do
  it {should be_running}
  its('public_ip_address') {should cmp HAPROXY_LB_IP}
  its('key_name') { should cmp 'ec2_key1' }
  its('image_id') { should eq 'ami-0f56279347d2fa43e' }
end

describe aws_security_groups do
    its('entries.count') { should eq 3}
end

describe aws_security_group(group_name: 'alation-web-sg') do
  it { should exist }
  its('group_name') { should eq 'alation-web-sg' }
  its('description') { should eq 'Security group that allows inbound and outbound traffic to webserver instances' }
end

describe aws_security_group(group_name: 'alation-lb-sg') do
  it { should exist }
  its('group_name') { should eq 'alation-lb-sg' }
  its('description') { should eq 'Security group that allows inbound and outbound traffic to loadbalancer instance' }
end

