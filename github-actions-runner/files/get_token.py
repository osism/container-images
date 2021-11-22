#!/usr/bin/python3

# This script fetches tokens to add new self-hosted
# GitHub action runners to organizations.
# It requires a GitHub App to be set up upfront with
# the below mentioned permissions.
# Using a GitHub App reduces the attack field
# massively in organization contexts. Normally
# a user personal access token with admin rights
# would be required to request new runner tokens.
#
# Organization permissions:
# - Self-hosted runners > Read & write
#
# Example usage:
# python3 get_token.py -h

import getopt
import jwt
import requests
import sys
import time


# JSON Web Token Authentication
def getJwt(private_key, app_id):
    # due to time-shifts set the tokens valid start time one minute before now
    iat = int(time.time()) - 60
    # Make the token expire after 10 minutes
    exp = int(time.time()) + 10 * 60
    encoded_jwt = jwt.encode({'iat': iat, 'exp': exp, 'iss': app_id},
                             private_key, algorithm="RS256")
    return encoded_jwt


# Each installation has an ID which is required to
# get an API token to talk to the orgs API
def getInstallationId(api_url, private_key, app_id, org):
    headers = {'Accept': 'application/vnd.github.v3+json',
               'Authorization': 'Bearer %s' % getJwt(private_key, app_id)}
    r = requests.get("%s/app/installations" % api_url, headers=headers)
    for item in r.json():
        if item['account']['login'] == org:
            installation_id = item['id']
            return installation_id

    # If the organization is not found, return 1
    return 1


# With the ID get the token specific for this org
def getInstallationToken(api_url, private_key, app_id, org):
    headers = {'Accept': 'application/vnd.github.v3+json',
               'Authorization': 'Bearer %s' % getJwt(private_key, app_id)}
    r = requests.post("%s/app/installations/%s/access_tokens" % (
                      api_url, getInstallationId(api_url,
                                                 private_key,
                                                 app_id,
                                                 org)), headers=headers)
    token = r.json()['token']
    return token


# Now use the token to get a runner token
def getRunnerToken(api_url, private_key, app_id, org):
    headers = {'Accept': 'application/vnd.github.v3+json',
               'Authorization': 'token %s' % getInstallationToken(api_url,
                                                                  private_key,
                                                                  app_id,
                                                                  org)}
    r = requests.post("%s/orgs/%s/actions/runners/registration-token" % (
                      api_url, org), headers=headers)
    token = r.json()['token']
    return token


def getHelp():
    print("Usage: ./get_token.py [OPTIONS]...")
    print("")
    print("  -o, --org         name of your organization in whichthe"
          "app is installed")
    print("  -i, --app-id      GitHub app id, e.g. 123456")
    print("  -k, --key-path    path to the RSA private key file from"
          "the GitHub app")
    print("  -u, --api-url     optional, set individual api URL like"
          "'https://api.github.com'")
    print("  -h, --help        display this short help and exit")
    print("")


def main(argv):
    api_url = "https://api.github.com"
    try:
        opts, _args = getopt.getopt(argv, "huk:i:o:", ["help",
                                                       "api-url",
                                                       "key-path=",
                                                       "app-id=",
                                                       "org="])
    except getopt.GetoptError:
        getHelp()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            getHelp()
            sys.exit()
        elif opt in ("-u", "--api-url"):
            if arg != "":
                api_url = arg
        elif opt in ("-k", "--key-path"):
            private_key = open(arg, 'r').read()
        elif opt in ("-i", "--app-id"):
            app_id = arg
        elif opt in ("-o", "--org"):
            org = arg

    return api_url, private_key, app_id, org


if __name__ == "__main__":
    api_url, private_key, app_id, org = main(sys.argv[1:])
    print(getRunnerToken(api_url, private_key, app_id, org))
