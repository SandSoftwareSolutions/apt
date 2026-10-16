# apt repository for Sand Software Solutions

Install **foundry** and **assay** with `apt` on Debian, Ubuntu and derivatives (amd64, arm64):

```console
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://sandsoftwaresolutions.github.io/apt/key.asc | sudo tee /etc/apt/keyrings/sandsoftwaresolutions.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/sandsoftwaresolutions.asc] https://sandsoftwaresolutions.github.io/apt stable main" | sudo tee /etc/apt/sources.list.d/sandsoftwaresolutions.list
sudo apt update
sudo apt install foundry assay
```

## How it works

A GitHub Actions workflow (`Update repository`) runs every six hours and on demand. It downloads the
`.deb` files attached to the newest releases of the repositories in `sources.txt`, builds the
indexes with `dpkg-scanpackages` and `apt-ftparchive`, signs the `Release` file and publishes the result
with GitHub Pages. To add a package, add its repository to `sources.txt` (its releases must carry `.deb`
files).

## The signing key

The repository is signed with a dedicated RSA 4096 key. The private key exists only as the
`APT_GPG_PRIVATE_KEY` secret of this repository; the public key is `key.asc` on the site. The workflow
does not run for pull requests, so forks cannot reach the secret.

Rotating the key: generate a new key, replace the secret, run the workflow, and tell users to download
`key.asc` again. The key expires on the date shown by `gpg --show-keys key.asc`; renew it before then.

## Local test

```console
GPG_KEY_ID=<fingerprint> scripts/build-repo.sh
```

needs `gh`, `gpg`, `apt-utils` and `dpkg-dev`, and builds `./site`.
