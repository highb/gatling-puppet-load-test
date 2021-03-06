# frozen_string_literal: true

# TODO: make this a Bolt task once abs_helper is available as a gem

require "optparse"
require "yaml"
require "json"
require "beaker-hostgenerator"
require "./setup/helpers/abs_helper.rb"
include AbsHelper # rubocop:disable Style/MixinUsage

REF_ARCH_TYPES = { large: "l", extra_large: "xl" }.freeze
DEFAULT_REF_ARCH = REF_ARCH_TYPES[:large]
DEFAULT_HA = false
DEFAULT_AWS_TAG_ID = "slv"
DEFAULT_OUTPUT_DIR = "./"
DEFAULT_PE_VERSION = "2019.1.0"
DEFAULT_AWS_INSTANCE_TYPE = "c5.2xlarge"
DEFAULT_AWS_VOLUME_SIZE = "80"

DESCRIPTION = <<~DESCRIPTION
  This script was created to assist in working with the pe_xl module (https://github.com/reidmv/reidmv-pe_xl).
  It provisions the nodes used by the module and generates the Bolt inventory and parameter files populated with the provisioned hosts.

  * Note: Because the script is designed to work with GPLT it sets up the environment without HA by default.

  EC2 hosts are provisioned for the following roles:
  * Core roles:
   - metrics
   - loadbalancer
   - master
   - puppet_db (for xl)
   - compiler_a
   - compiler_b

  * HA roles:
   - master_replica
   - puppet_db_replica

DESCRIPTION

DEFAULTS = <<~DEFAULTS

  The following defaults values are used if the options are not specified:
  * REF_ARCH (-a, --ref_arch): #{DEFAULT_REF_ARCH}
  * HA (--ha): #{DEFAULT_HA}
  * AWS_TAG_ID (-i, --id): #{DEFAULT_AWS_TAG_ID}
  * OUTPUT_DIR (-o, --output_dir): #{DEFAULT_OUTPUT_DIR}
  * PE_VERSION (-v, --pe_version): #{DEFAULT_PE_VERSION}
  * AWS_INSTANCE_TYPE (-t, --type): #{DEFAULT_AWS_INSTANCE_TYPE}
  * AWS_VOLUME_SIZE (-s, --size): #{DEFAULT_AWS_VOLUME_SIZE}

DEFAULTS

options = {}

# Note: looks like 'Store options to a Hash' doesn't work in Ruby 2.3.0.
# https://ruby-doc.org/stdlib-2.6.3/libdoc/optparse/rdoc/OptionParser.html
#  `end.parse!(into: options)`
# TODO: update to use '(into: options)' after Ruby update
# TODO: error when invalid options are specified
# TODO: re-order the options?
OptionParser.new do |opts|
  opts.banner = "Usage: provision_pe_xl_nodes.rb [options]"

  opts.on("-h", "--help", "Display the help text") do
    puts DESCRIPTION
    puts opts
    puts DEFAULTS
    exit
  end

  opts.on("--ha", "Specifies that the environment should be set up for HA")

  # TODO: noop and test options are mutually exclusive;
  # error when both are specified?
  #
  # omitted short versions to avoid collisions
  opts.on("--noop", "Run in no-op mode") { options[:noop] = true }
  opts.on("--test", "Use test data rather than provisioning hosts") { options[:test] = true }

  opts.on("--ha", "Deploy HA environment") { options[:ha] = true }

  opts.on("-i", "--id ID", String, "The value for the AWS 'id' tag") do |id|
    options[:id] = id
  end

  # TODO: verify these
  opts.on("-o", "--output_dir DIR", String, "The directory where the Bolt files should be written") do |output_dir|
    options[:output_dir] = output_dir
  end

  opts.on("-v", "--pe_version VERSION", String, "The PE version to install") do |pe_version|
    options[:pe_version] = pe_version
  end

  opts.on("-t", "--type TYPE", String, "The AWS EC2 instance type to provision") do |type|
    options[:type] = type
  end

  opts.on("-s", "--size SIZE", Integer, "The AWS EC2 volume size to specify") do |size|
    options[:size] = size
  end

  options[:ref_arch] = DEFAULT_REF_ARCH
  opts.on("-a", "--ref_arch REF_ARCH", String, "The reference architecture type to provision (l, xl)") do |ref_arch|
    allowable_ref_arch = REF_ARCH_TYPES.values
    raise "ref_arch must be in #{allowable_ref_arch}" unless allowable_ref_arch.include? ref_arch

    options[:ref_arch] = ref_arch
  end
end.parse!

raise "Large ref_arch doesn't currently support HA" if options[:ref_arch] == REF_ARCH_TYPES[:large] && options[:ha]

ROLES_CORE = %w[metrics
                loadbalancer
                master
                compiler_a
                compiler_b].freeze

ROLES_XL = %w[puppet_db].freeze

ROLES_HA = %w[master_replica
              puppet_db_replica].freeze

roles = ROLES_CORE
roles = ROLES_CORE + ROLES_XL if options[:ref_arch] == REF_ARCH_TYPES[:extra_large]

if options[:ha]
  HA = true
  roles += ROLES_HA
else
  HA = DEFAULT_HA
end

ROLES = roles.freeze

NOOP = options[:noop] || false
TEST = options[:test] || false
PROVISIONING_TXT = NOOP || TEST ? "Would have provisioned" : "Provisioning"

AWS_TAG_ID = options[:id] || DEFAULT_AWS_TAG_ID
OUTPUT_DIR = options[:output_dir] || DEFAULT_OUTPUT_DIR
PE_VERSION = options[:pe_version] || DEFAULT_PE_VERSION

# TODO: allow different type / size for each node?
AWS_INSTANCE_TYPE = options[:type] || DEFAULT_AWS_INSTANCE_TYPE
AWS_VOLUME_SIZE = options[:size] || DEFAULT_AWS_VOLUME_SIZE

# TODO: move to spec when test cases are implemented
# for now this allows testing of the create_pe_xl_bolt_files method without provisioning
TEST_HOSTS_HA = [{ role: "puppet_db", hostname: "ip-10-227-3-22.test.puppet.net" },
                 { role: "compiler_b", hostname: "ip-10-227-1-195.test.puppet.net" },
                 { role: "puppet_db_replica", hostname: "ip-10-227-3-158.test.puppet.net" },
                 { role: "master", hostname: "ip-10-227-3-127.test.puppet.net" },
                 { role: "compiler_a", hostname: "ip-10-227-3-242.test.puppet.net" },
                 { role: "master_replica", hostname: "ip-10-227-1-82.test.puppet.net" }].freeze

TEST_HOSTS_NO_HA = [{ role: "puppet_db", hostname: "ip-10-227-3-22.test.puppet.net" },
                    { role: "compiler_b", hostname: "ip-10-227-1-195.test.puppet.net" },
                    { role: "master", hostname: "ip-10-227-3-127.test.puppet.net" },
                    { role: "compiler_a", hostname: "ip-10-227-3-242.test.puppet.net" }].freeze

PROVISION_MESSAGE = <<~PROVISION_MESSAGE

  #{PROVISIONING_TXT} pe_xl nodes with the following options:
    REF_ARCH: #{options[:ref_arch]}
    HA: #{HA}
    Output directory for Bolt inventory and parameter files: #{OUTPUT_DIR}
    PE version: #{PE_VERSION}
    AWS EC2 id tag: #{AWS_TAG_ID}
    AWS EC2 instance type: #{AWS_INSTANCE_TYPE}
    AWS EC2 volume size: #{AWS_VOLUME_SIZE}

PROVISION_MESSAGE

NOOP_MESSAGE = "*** Running in no-op mode ***"
NOOP_EXEC = <<~NOOP_EXEC
  Would have called:

    hosts = provision_hosts_for_roles(#{ROLES},
                                      #{AWS_TAG_ID},
                                      #{AWS_SIZE},
                                      #{AWS_VOLUME_SIZE})

  to provision the hosts, then:

    create_pe_xl_bolt_files(hosts, #{OUTPUT_DIR})

  to create the Bolt inventory and parameter files.

NOOP_EXEC

TEST_MESSAGE = "*** Running in test mode ***"

# This is the main entry point to the provision_pe_xl_nodes.rb script
# It provisions EC2 hosts for pe_xl using ABS (via abs_helper)
#
# TODO: more...
#
# @author Bill Claytor
#
# @example
#   provision_pe_xl_nodes
#
def provision_pe_xl_nodes
  puts NOOP_MESSAGE if NOOP
  puts TEST_MESSAGE if TEST
  puts PROVISION_MESSAGE

  # TODO: update provision_hosts_for_roles to generate last_abs_resource_hosts.log
  # and generate Beaker hosts files
  if NOOP
    puts NOOP_EXEC
  else
    hosts = if TEST
              HA ? TEST_HOSTS_HA : TEST_HOSTS_NO_HA
            else
              provision_hosts_for_roles(ROLES, AWS_TAG_ID, AWS_SIZE, AWS_VOLUME_SIZE)
            end

    create_pe_xl_bolt_files(hosts, OUTPUT_DIR)
  end
end

# Creates the Bolt inventory file (nodes.yaml) and
# parameters file (params.json) for the specified hosts
#
# Note: designed to use the output of provision_hosts_for_roles
#
# @author Bill Claytor
#
# @param [Array<Hash>] hosts The provisioned hosts
# @param [String] output_dir The directory where the file should be written
#
# @example
#   hosts = provision_hosts_for_roles(roles)
#   create_pe_xl_bolt_files(hosts)
#
# TODO: move to abs_helper or elsewhere?
# TODO: spec test(s)
def create_pe_xl_bolt_files(hosts, output_dir)
  create_nodes_yaml(hosts, output_dir)
  create_params_json(hosts, output_dir)
  create_beaker_config(hosts, output_dir)
end

# Creates the Bolt inventory file (nodes.yaml) for the specified hosts
#
# Note: designed to use the output of provision_hosts_for_roles
#
# @author Bill Claytor
#
# @param [Array<Hash>] hosts The provisioned hosts
# @param [String] output_dir The directory where the file should be written
#
# @example
#   hosts = provision_hosts_for_roles(roles)
#   create_nodes_yaml(hosts, output_dir)
def create_nodes_yaml(hosts, output_dir)
  data = { "groups" => [
    { "name"   => "pe_xl_nodes",
      "config" => { "transport" => "ssh",
                    "ssh"       => { "host-key-check" => false,
                                     "user"           => "root" } } }
  ] }

  output_path = "#{File.expand_path(output_dir)}/nodes.yaml"

  data["groups"][0]["nodes"] = hosts.map { |h| { "name" => h[:hostname], "alias" => h[:role] } }

  puts "Writing #{output_path}"
  puts

  File.write(output_path, data.to_yaml)

  check_nodes_yaml(output_path) if TEST
end

# Checks the nodes.yaml file to ensure it has been written correctly
#
# @author Bill Claytor
#
# @param [String] file The 'nodes.yaml' file to check
#
# @example
#   check_nodes_yaml(file)
def check_nodes_yaml(file)
  puts "Checking #{file}..."
  puts

  contents = File.read file
  puts contents
  puts

  puts "Parsing YAML..."
  puts

  yaml = YAML.safe_load(contents, [Symbol])
  puts yaml
  puts

  puts "Verifying YAML..."
  nodes = yaml["groups"][0]["nodes"]

  raise "Invalid pe_xl inventory file; must contain non-empty `nodes` element" if nodes.nil? || nodes.empty?

  puts
  puts "Verified parameter 'nodes':"
  puts nodes
  puts
end

# Creates the Bolt parameters file (params.json) for the specified hosts
#
# Note: designed to use the output of provision_hosts_for_roles
#
# @author Bill Claytor
#
# @param [Array<Hash>] hosts The provisioned hosts
# @param [String] output_dir The directory where the file should be written
#
# @example
#   hosts = provision_hosts_for_roles(roles)
#   create_params_json(hosts, output_dir)
def create_params_json(hosts, output_dir)
  master, = hosts.map { |host| host[:hostname] if host[:role] == "master" }.compact
  pdb, = hosts.map { |host| host[:hostname] if host[:role] == "puppet_db" }.compact
  master_replica, = hosts.map { |host| host[:hostname] if host[:role] == "master_replica" }.compact
  pdb_replica, = hosts.map { |host| host[:hostname] if host[:role] == "puppet_db_replica" }.compact
  compilers = hosts.map { |host| host[:hostname] if host[:role].include? "compiler" }.compact
  loadbalancer, = hosts.map { |host| host[:hostname] if host[:role] == "loadbalancer" }.compact

  dns_alt_names = ["puppet", master, loadbalancer]
  pool_address = loadbalancer || master

  pe_xl_params = {
    install: true,
    configure: true,
    upgrade: false,
    master_host: master,
    puppetdb_database_host: pdb,
    master_replica_host: master_replica,
    puppetdb_database_replica_host: pdb_replica,
    compiler_hosts: compilers,

    console_password: "puppetlabs",
    dns_alt_names: dns_alt_names,
    compiler_pool_address: pool_address,
    version: PE_VERSION
  }.compact

  params_json = JSON.pretty_generate(pe_xl_params)
  output_path = "#{File.expand_path(output_dir)}/params.json"

  puts
  puts "Writing #{output_path}"
  puts

  File.write(output_path, params_json)

  check_params_json(output_path) if TEST
end

# Checks the params.json file to ensure it has been written correctly
#
# @author Bill Claytor
#
# @param [String] file The 'params.json' file to check
#
# @example
#   check_params_json(file)
def check_params_json(file)
  puts "Checking #{file}..."
  puts

  contents = File.read(file)
  puts contents

  puts "Parsing JSON..."
  puts

  json = JSON.parse contents
  puts json
  puts

  puts "Verifying JSON..."
  install = json["install"]

  unless [true, false].include? install
    raise "Invalid pe_xl parameter file; must contain `install` parameter specifying either `true` or `false`"
  end

  puts "Verified parameter 'install': #{install}"
  puts
end

def create_beaker_config(hosts, output_dir)
  beaker_os = "redhat7-64"
  # define beaker roles for each host
  beaker_role_map = { "master"            => %w[master dashboard],
                      "master_replica"    => "master",
                      "puppet_db"         => "database",
                      "puppet_db_replica" => "database",
                      "compiler_a"        => "compile_master",
                      "compiler_b"        => "compile_master",
                      "loadbalancer"      => "loadbalancer",
                      "metrics"           => "metric" }

  beaker_roles = beaker_role_map.keys

  # seed beaker roles
  hosts.each do |h|
    h[:beaker] = []
  end

  master = hosts.detect { |h| h[:role] == "master" }
  m_index = hosts.index(master)

  # Add beaker roles to host hashes in order to associate them with the correct
  # host when constucting the beaker-host-generator string.
  until beaker_roles.empty?
    role_found = 0
    role = beaker_roles.pop
    hosts.each do |h|
      if h[:role] == role
        h[:beaker] << beaker_role_map[role]
        role_found += 1
      end
    end
    # assign unallocated database role to master
    hosts[m_index][:beaker] << beaker_role_map[role] \
      if role_found.zero? && %w[puppet_db puppet_db_replica].include?(role)
  end

  hosts.each do |h|
    h[:beaker] = h[:beaker].flatten.uniq.join(",")
  end

  # Build beaker-hg string
  bhg = BeakerHostGenerator::Generator.new
  bhg_string = +""
  hosts.each do |h|
    options = ["hostname=#{h[:hostname]}"]
    options << "ports=\[2003\,7777\,80\]" if h[:role] == "metrics"

    bhg_string << beaker_os + h[:beaker] + ".{" + options.join("\,") + "}-"
  end
  bhg_string = bhg_string.chomp("-")
  beaker_yaml = bhg.generate(bhg_string, hypervisor: "none").to_yaml
  output_path = "#{File.expand_path(output_dir)}/beaker.cfg"

  puts
  puts "Writing #{output_path}"
  puts

  File.write(output_path, beaker_yaml)

  puts beaker_yaml if TEST
end

provision_pe_xl_nodes if $PROGRAM_NAME == __FILE__
