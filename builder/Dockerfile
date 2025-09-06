FROM alpine:3.18
RUN apk add --no-cache git openssh-client bash curl
WORKDIR /builder
COPY build-and-deploy.sh /builder/build-and-deploy.sh
RUN chmod +x /builder/build-and-deploy.sh
ENTRYPOINT ["/builder/build-and-deploy.sh"]
