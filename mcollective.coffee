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
#   HUBOY_PUPPET_MCOLLECTIVE_CFG  - set this env variable to the path to your mcollective config file on the mcollective host
# Commands:
#   mco ping: get list of hosts to run mco commands against
#   mco puppet run <target host>
#   mco puppet run <regex for group of hosts>
#   mco puppet status <target host>
#   mco puppet status <regex for group of hosts>
#   mco help
# 
# Notes:
#   Requires root access (NOPASSWD) to the mcollective host
#   Feel free to modify for your environment and security constraints
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

    ssh_string = "#{mco_base_cmd} puppet -v -j runall 10 -I #{target_envs}'"
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


