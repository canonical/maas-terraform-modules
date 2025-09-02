# Troubleshooting Guide

## SSH Access to Juju machines

The Terraform modules are deploying charmed MAAS on Juju machines. The SSH access to these machines can be performed either via Juju CLI or directly by the user. In both cases, direct network connectivity between the user system and the Juju machines should be guaranteed.

### Juju CLI SSH access

If there is a Juju snap available and authenticated to the Juju controller, the SSH key of the Juju client should be added to the charmed MAAS model. The public part of the SSH key is available in the Juju local directory: `~/.local/share/juju/ssh/juju_id_rsa.pub`.

```bash
cat ~/.local/share/juju/ssh/juju_id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9n8t0ybjn3n1LrCTg2KStppQGS1IcZnwAZys1/TVSbAyruTzP6YeaAn91Uoy0TMvcQ3qfxeCmerR1cFW7E1ZxlwQsutwYzGHU5L8MhSwARAWQPRRNDPFtXpw1eb5WslmnirvE6BHBeKxQc9romJ7SxdgNKaPeq/qIvqiC3VbvtG4fHF0vsrW+bXPYcwtmw1BUNV83vZtVBt2/wC8/P9Y4Ym4vsvTDT99mbKJlt7egGWJWqC0JI04hUmCC4O1FH+8pCXYpSnrHNAZicKIpP6pVprcWYIqV7aeWUsGqVNFKJSevgLwIlzyv8lc7tf/nrsc/RU6UVoXPnVnJJWsmk3eymVZT3mTa+XmpKr5kJaORkGkF8P0jTYwXT/iOS6nuvctOq1HLUx0JLEU4Xv3qZdCbZAKhuaz7YfWSYUNVQpUUwpZCfNyQgmM2OxTxQANyxF36UM2himMeME+8D2/H8bv9s1DT6CIBSg4WzGs8SK0ytCy3PhUikSzwUwA7DDRNeAP8V5uzm/iOmYrimCil1E5V6TRxOLMIOH1PftObUqoqMyxFdcHsA9tE7RiydZtcdnH+c2GGwKDTbMDwMM4a+9RWrWeOWTNTxgrGIAIZCG6Ixjs+CgVdK9XhGEYDw5aQJC6Zss7+YuAqmJRqpQB+Q8la8YMWg6jVxgPABCJ6OMTOKQ== juju-client-key
```

> [!Note]
> Juju does not allow adding the key with the `juju-client-key` comment. As such, it has to be removed.

```bash
juju add-ssh-key "$(cat ~/.local/share/juju/ssh/juju_id_rsa.pub  | awk '{print $1 " " $2;}')"
juju ssh-keys
Keys used in model: admin/maas
2e:21:d4:af:83:47:0b:10:9f:a1:bc:42:0e:9c:76:7c
juju ssh maas-region/0
```

### SSH access without Juju CLI

Juju supports adding to the model any SSH key by its public part, or importing it directly from GitHub or Launchpad.

```bash
# A SSH key from the system
juju add-ssh-key "$(cat ~/.ssh/id_ed25519.pub)"
juju ssh-keys
Keys used in model: admin/maas
24:a5:d6:46:97:13:c8:f9:17:58:3c:c8:99:15:71:82 (ubuntu@maas-bastion)
ssh -i ~/.ssh/id_ed25519 ubuntu@10.240.246.5

# One or more SSH keys of a GitHub user
juju import-ssh-key gh:sample-user
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user@github/12302123 # ssh-import-id gh:sample-user)

# One or more SSH keys of a Launchpad user
juju import-ssh-key lp:sample-user
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user # ssh-import-id lp:sample-user)
```

### SSH key removal from the model

```bash
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user # ssh-import-id lp:sample-user)
juju remove-ssh-key 74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43
juju ssh-keys
No keys to display.
```
