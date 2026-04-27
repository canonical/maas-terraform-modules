## Uploading a custom image to MAAS

This guide walks through building a custom image using `packer-maas` and uploading it to a MAAS instance.

### Prerequisites

Before starting, ensure you have met all [prerequisites](../../README.md#prerequisites) in the root README. You will need a LXD cloud, so consider using [LXD](https://canonical.com/lxd) or [MicroCloud](https://canonical.com/microcloud).

You will also need sufficient resources to meet the `packer-maas` [prerequisites](https://github.com/canonical/packer-maas/blob/main/README.md#prerequisites).

### Installing packer-maas

Clone the `packer-maas` repository:

```bash
git clone https://github.com/canonical/packer-maas.git
cd packer-maas
```

Then follow the installation instructions in the repository’s `README.md`.

In particular, installing [Packer](https://developer.hashicorp.com/packer/install) requires:

1. Importing the HashiCorp GPG signing key
2. Adding the HashiCorp package repository
3. Installing the `packer` package

### Build the MAAS image

The [exact steps](https://canonical.com/maas/docs/how-to-build-custom-images) depend on the image you want to build.

Refer to the relevant example, such as the [Ubuntu configuration](https://github.com/canonical/packer-maas/tree/main/ubuntu), and run the appropriate `make` or `packer build` command as described in the target instructions.

### Set ownership

By default, the `packer-maas` build process produces an image tarball owned by the `root` user. You must ensure it is owned by the same user that will run the MAAS CLI upload command:

```bash
chown $maas_user:$maas_user $image_file
```

Failing to do this will result in permission errors during upload, which is exactly as fun as it sounds.

### Configure MAAS CLI access

Log in to your MAAS instance using the CLI. For example, follow the official guide:

* [https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-cli-setup](https://canonical.com/maas/docs/how-to-get-maas-up-and-running#p-9034-cli-setup)

This configures your API key and profile so you can interact with MAAS programmatically.

### Upload the image

Use the upload command provided by your chosen image configuration. For example:

* [https://github.com/canonical/packer-maas/tree/main/ubuntu#uploading-images-to-maas](https://github.com/canonical/packer-maas/tree/main/ubuntu#uploading-images-to-maas)

The command will have a structure similar to:

```bash
maas $PROFILE boot-resources create \
    name="$image_name" \
    title="$image_title" \
    architecture="$architecture" \
    filetype="$file_type" \
    content@=$image_file_path
```

> **Note:** The upload process can take a significant amount of time and may appear to stall. In most cases, it is still progressing.

### Networking considerations

When uploading through HAProxy:

* Connections are sticky by default
* A client will continue to connect to the same backend server unless that server becomes unavailable
