# SSH Access to Juju machines

The SSH access to charmed MAAS machines can be performed either via Juju CLI or directly from the user system. In both cases, direct network connectivity between the user system and the Juju machines should be guaranteed.

By default, no SSH key is added in the machines. As such, any attempt to connect via SSH will return a permission denied error.

Via Juju CLI:

```bash
juju ssh maas-region/0
ubuntu@10.240.246.5: Permission denied (publickey).
```

Via SSH:

```bash
MACHINE_IP=$(juju status maas-region/0 --format json | jq -r '.machines.[].["ip-addresses"][0]')
ssh ubuntu@$MACHINE_IP
ubuntu@10.240.246.5: Permission denied (publickey).
```

## Adding keys to the model

To be able to SSH to the machines, at least one valid SSH key should be added to the Juju model. Juju supports adding SSH keys by providing their public part, or by importing them from a GitHub or Launchpad account.

> [!Note]
> The SSH keys can be added to the model by using a Juju snap that is authenticated to the Juju controller. Assuming that Juju is bootstrapped with `juju-bootstrap` module, the command to add the key(s) can be executed from the same host that used to apply the module.

### Adding a local SSH key

```bash
juju add-ssh-key "$(cat ~/.ssh/id_ed25519.pub)"
juju ssh-keys
Keys used in model: admin/maas
24:a5:d6:46:97:13:c8:f9:17:58:3c:c8:99:15:71:82 (ubuntu@maas-bastion)
```

### Importing a SSH key from GH/LP

```bash
# GitHub
juju import-ssh-key gh:sample-user
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user@github/12302123 # ssh-import-id gh:sample-user)

# Launchpad
juju import-ssh-key lp:sample-user
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user # ssh-import-id lp:sample-user)
```

## SSH Access

After adding at least one key in the model, then SSH access is granted.

Via Juju CLI:

```bash
juju ssh maas-region/0 -i ~/.ssh/id_ed25519
...
ubuntu@juju-8d3596-1:~$
```

Via SSH:

```bash
MACHINE_IP=$(juju status maas-region/0 --format json | jq -r '.machines.[].["ip-addresses"][0]')
ssh -i ~/.ssh/id_ed25519 ubuntu@$MACHINE_IP
...
ubuntu@juju-8d3596-1:~$
```

## Manage SSH keys

Once added to the model, the SSH keys can be listed and/or removed.

```bash
juju ssh-keys
Keys used in model: admin/maas
74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43 (sample-user # ssh-import-id lp:sample-user)
juju remove-ssh-key 74:96:43:55:b3:3d:bd:bf:f3:74:96:43:55:74:96:43
juju ssh-keys
No keys to display.
```

## Resources

- [Juju SSH key reference](https://documentation.ubuntu.com/juju/3.6/reference/ssh-key/#ssh-key)
- [Juju management of SSH keys](https://documentation.ubuntu.com/juju/3.6/howto/manage-ssh-keys/#manage-ssh-keys)
