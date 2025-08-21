# Multi-stage build for Cabinet consensus system
FROM golang:1.17-alpine AS builder

# Install dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the cabinet binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cabinet .

# Final stage - minimal runtime image
FROM alpine:latest

# Install ca-certificates for HTTPS connections if needed
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the cabinet binary from builder stage
COPY --from=builder /app/cabinet .

# Copy configuration files
COPY --from=builder /app/config/ ./config/
COPY --from=builder /app/tpccConfig.json ./
COPY --from=builder /app/ycsb/ ./ycsb/

# Create directories for logs and data
RUN mkdir -p /root/logs /root/data

# Cabinet uses RPC ports (default 10000-10009 range)
# Expose the port range - you'll specify exact port via environment
EXPOSE 10000-10009

# Environment variables with defaults
ENV CABINET_ID=0
ENV CABINET_SERVERS=5
ENV CABINET_CONFIG_PATH=./config/cluster_docker.conf
ENV CABINET_BATCH_SIZE=1
ENV CABINET_LOG_LEVEL=info
ENV CABINET_EVAL_TYPE=0
ENV CABINET_ENABLE_PRIORITY=true

# Default command - can be overridden
CMD ["sh", "-c", "./cabinet -id=${CABINET_ID} -n=${CABINET_SERVERS} -path=${CABINET_CONFIG_PATH} -b=${CABINET_BATCH_SIZE} -log=${CABINET_LOG_LEVEL} -et=${CABINET_EVAL_TYPE} -ep=${CABINET_ENABLE_PRIORITY}"]
