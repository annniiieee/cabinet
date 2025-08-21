#!/bin/bash

# Cabinet Docker Cluster Management Script

function show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build       Build Cabinet Docker images"
    echo "  start       Start Cabinet cluster"
    echo "  stop        Stop Cabinet cluster"
    echo "  restart     Restart Cabinet cluster"
    echo "  logs        Show logs for all services"
    echo "  status      Show cluster status"
    echo "  scale       Scale followers (e.g., scale 7)"
    echo "  clean       Clean up containers and images"
    echo ""
    echo "Options:"
    echo "  -n NUM      Number of total servers (default: 5)"
    echo "  -b SIZE     Batch size (default: 10)"
    echo "  -et TYPE    Evaluation type: 0=plain, 1=tpcc, 2=mongodb (default: 0)"
    echo "  -log LEVEL  Log level: debug, info, warn, error (default: info)"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 start -n 7 -b 100"
    echo "  $0 logs cabinet-leader"
    echo "  $0 scale 7"
}

function build_images() {
    echo "Building Cabinet Docker images..."
    docker-compose build
}

function start_cluster() {
    local servers=${1:-5}
    local batch_size=${2:-10}
    local eval_type=${3:-0}
    local log_level=${4:-info}
    
    echo "Starting Cabinet cluster with $servers servers..."
    
    # Update environment variables
    export CABINET_SERVERS=$servers
    export CABINET_BATCH_SIZE=$batch_size
    export CABINET_EVAL_TYPE=$eval_type
    export CABINET_LOG_LEVEL=$log_level
    
    # Create necessary directories
    mkdir -p logs data
    
    # Start followers first, then leader
    echo "Starting followers..."
    docker-compose up -d cabinet-follower-1 cabinet-follower-2 cabinet-follower-3 cabinet-follower-4
    
    # Wait a bit for followers to be ready
    echo "Waiting for followers to initialize..."
    sleep 5
    
    echo "Starting leader..."
    docker-compose up -d cabinet-leader
    
    echo "Cabinet cluster started successfully!"
    echo "Leader: http://localhost:10000"
    echo "Followers: http://localhost:10001-10004"
}

function stop_cluster() {
    echo "Stopping Cabinet cluster..."
    docker-compose down
}

function restart_cluster() {
    stop_cluster
    sleep 2
    start_cluster $@
}

function show_logs() {
    local service=${1:-}
    if [ -z "$service" ]; then
        docker-compose logs -f
    else
        docker-compose logs -f $service
    fi
}

function show_status() {
    echo "Cabinet Cluster Status:"
    echo "======================="
    docker-compose ps
    echo ""
    echo "Network Status:"
    docker network ls | grep cabinet
    echo ""
    echo "Container Resources:"
    docker stats --no-stream | grep cabinet
}

function scale_cluster() {
    local total_servers=${1:-5}
    local followers=$((total_servers - 1))
    
    echo "Scaling to $total_servers total servers ($followers followers)..."
    
    # This is a simplified scaling - for production, you'd need dynamic config generation
    if [ $followers -gt 4 ]; then
        echo "Warning: Current docker-compose.yml supports max 4 followers"
        echo "You need to modify docker-compose.yml to add more follower services"
    fi
    
    docker-compose up -d --scale cabinet-follower-1=$followers
}

function clean_cluster() {
    echo "Cleaning up Cabinet cluster..."
    docker-compose down -v --rmi all
    docker system prune -f
}

# Parse command line arguments
case "$1" in
    build)
        build_images
        ;;
    start)
        shift
        # Parse options
        servers=5
        batch_size=10
        eval_type=0
        log_level=info
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                -n)
                    servers="$2"
                    shift 2
                    ;;
                -b)
                    batch_size="$2"
                    shift 2
                    ;;
                -et)
                    eval_type="$2"
                    shift 2
                    ;;
                -log)
                    log_level="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    show_help
                    exit 1
                    ;;
            esac
        done
        
        start_cluster $servers $batch_size $eval_type $log_level
        ;;
    stop)
        stop_cluster
        ;;
    restart)
        shift
        restart_cluster $@
        ;;
    logs)
        show_logs $2
        ;;
    status)
        show_status
        ;;
    scale)
        scale_cluster $2
        ;;
    clean)
        clean_cluster
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
