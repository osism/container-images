# building the images locally

```sh
podman build --arch=amd64 -t aptly -f Containerfile-aptly
podman build --arch=amd64 -t aptly-nginx -f Containerfile-nginx
podman build --arch=amd64 -t aptly-prepare -f Containerfile-prepare
```

## rebuilding for developing

```sh
podman rm -f aptly && podman build --arch=amd64 -t aptly -f Containerfile-aptly && podman run -d --name aptly aptly && podman exec -it aptly bash
podman rm -f aptly-nginx && podman build --arch=amd64 -t aptly-nginx -f Containerfile-nginx && podman run -d -p 8080:80 --name aptly-nginx aptly-nginx && podman exec -it aptly-nginx bash
podman rm -f aptly-prepare && podman build --arch=amd64 -t aptly-prepare -f Containerfile-prepare && podman run -d --name aptly-prepare aptly-prepare && podman exec -it aptly-prepare bash
```
