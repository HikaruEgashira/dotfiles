FROM alpine

ENV USER="vscode"
RUN apk --no-cache add sudo curl xz
RUN addgroup -S appgroup && adduser -S $USER -G appgroup && echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER $USER
