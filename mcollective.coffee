# Description:
#   * Hubot interface to mcollective for puppet
#   * Currently able to start puppet runs and get status
#     of one server or collection of servers using an mco
#     regex filter
#   * Can also discover nodes using ping
#
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_PUPPET_MCOLLECTIVE_HOST - set this env variable to the hostname of your mcollective host
#   HUBOT_PUPPET_MCOLLECTIVE_CMD  - set this env variable to the path to your mco executable on the mcollective host
#   HUBOY_PUPPET_MCOLLECTIVE_USER - set this env variable to the username used by ssh to connect  to your mcollective host
#   HUBOY_PUPPET_MCOLLECTIVE_CFG  - set this env variable to the path to your mcollective client config file on the mcollective host (if you use ssl authentication you need also access to the ssl keys, defined in the config file)
#
# Commands:
#   mco ping: get list of hosts to run mco commands against
#   mco puppet run <target host>
#   mco puppet run <regex for group of hosts>
#   mco puppet status <target host>
#   mco puppet status <regex for group of hosts>
#   mco help
#
# Notes:
#   The mcollective host can be any machine with access to the mcollective.
#   broker and the mcollective credentials and client.cfg config file.
#   Requires ssh without password (using ssh key) to the mcollective host.
#   Feel free to modify for your environment and security constraints.
#
# Author:
#   pzim <Phil Zimmerman>
# Maintainer:
#   Leonardo Rodrigues de Mello <l@lmello.eu.org> 2015
{spawn, exec}  = require 'child_process'
module.exports = (robot) ->


  mco_host     = process.env.HUBOT_PUPPET_MCOLLECTIVE_HOST
  mco_cmd      = process.env.HUBOT_PUPPET_MCOLLECTIVE_CMD
  mco_user     = process.env.HUBOT_PUPPET_MCOLLECTIVE_USER
  mco_cfg      = process.env.HUBOT_PUPPET_MCOLLECTIVE_CFG

# The single quote is required for the ssh command to work
# on the command invocation it is required to close the single quote
  mco_base_cmd = "ssh -t #{mco_user}@#{mco_host} '#{mco_cmd} -c #{mco_cfg}"

  ssh_exec = (ssh_cmd, cb) ->
    child = exec ssh_cmd, (err, stdout, stderr) ->
      if !err
        result_text = stdout
      else
        result_text = stderr
      cb result_text

  robot.respond /mco ping/i, (msg) ->
    console.log("#{mco_base_cmd} ping")

    exec "#{mco_base_cmd} ping'", (err, stdout, stderr) ->
      if err
        msg.send "failed to run mco: #{stderr}"
      else
        msg.send stdout

  robot.respond /mco puppet run (.*)/i, (msg) ->
    target_envs = msg.match[1]
    console.log("target_envs = #{target_envs}")

    ssh_string = "#{mco_base_cmd} puppet -v -j runonce -I #{target_envs}'"
    console.log ("#{ssh_string}")
    results = ""
    ssh_exec ssh_string, (output) ->
      responses = JSON.parse(output)
      for item in responses
        host = item.sender
        console.log("host = #{host}")
        status = item.data.summary
        console.log("status = #{status}")
        tmpout = "host: #{host}, result: #{status}\n"
        results = results + tmpout
      msg.send results


  robot.respond /mco puppet status (.*)/i, (msg) ->
    target_envs = msg.match[1]
    console.log("target_envs = #{target_envs}")

    ssh_string = "#{mco_base_cmd} puppet -j -I #{target_envs} status'"
    console.log ("#{ssh_string}")
    ssh_exec ssh_string, (output) ->
      msg.send output

  #Event processor to run commands
  # this is only a stub idea does not work for now, incomplete.
  # this would be used by mcollective script and could allow
  # other hubot scripts to call mcollective commands.
  # it should be called with hubot.emit "mco:runcommand" (msg.recipient.user, room, mcommand)
  robot.on 'mco:runcommand', (user,room, mcommand) ->
    # this is for safety, we avoid to run mcollective commands without filters.
    robot.messageRoom room, "You need at least one filter to run mco commands"  unless mcommand.filter.class[0] or mcommand.filter.facts or mcommand.filter.identity[0]
    robot.messageRoom room, "You need to send the mco_config file to run commands" unless mcommand.mco_config
    robot.messageRoom room, "You need to send the mcollective agent name " unless mcommand.agent.name
    mco_full_cmd = "#{mco_base_cmd}"
    mco_full_cmd += " #{mcommand.mco_config}"
    mco_full_cmd += " #{mcommand.agent.name}"
    mco_full_cmd += " #{mcommand.agent.action}" if mcommand.agent.action
    # Add class filters to the mco command
    mcommand.filter.class map (class_filter) -> mco_full_cmd += " -C #{class_filter}"
    # add facts filters to the mco command
    Object.keys(mcommand.filter.facts).map (fact_key) -> mco_full_cmd += " -F #{fact_key}=#{mcommand.filter.facts[fact_key]}"
    # Add identity filters to the mco command
    mcommand.filter.identity.map (identity_filter) -> mco_full_cmd += " -I #{identity_filter}"
    # close single quote this is needed for ssh command.
    mco_full_cmd += "'"
    if robot.auth.hasRole(user, "mco-#{agent}-#{action}") or robot.auth.hasRole(user, "mco-#{agent}-superuser")
      console.log ("user #{user} told to run #{mco_full_command}")
    else
      robot.messageRoom room, "Username does not have permission to run #{mco_full_cmd}, you need role mco-#{agent}-#{action} or mco-#{agent}-superuser"
      console.log ("Username does not have permission to run #{mco_full_cmd}, you need role mco-#{agent}-#{action} or mco-#{agent}-superuser")

