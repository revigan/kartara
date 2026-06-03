FROM alpine:3.19

# PocketBase version
ARG PB_VERSION=0.23.4

RUN apk add --no-cache \
    unzip \
    ca-certificates \
    wget

# Download & extract PocketBase binary
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/ && \
    chmod +x /pb/pocketbase && \
    rm /tmp/pb.zip

# Buat direktori data (akan di-mount sebagai Railway volume)
RUN mkdir -p /pb/pb_data

EXPOSE 8090

# Jalankan PocketBase, mendengarkan di semua interface agar Railway bisa mengaksesnya
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090"]
