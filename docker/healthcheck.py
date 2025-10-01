#!/usr/bin/env python3
"""
BUDDY Health Check Script
Monitors the health of the BUDDY backend service
"""

import asyncio
import json
import sys
import time
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

import aiohttp
import psutil


class BuddyHealthCheck:
    def __init__(self, host: str = "localhost", port: int = 8000):
        self.host = host
        self.port = port
        self.base_url = f"http://{host}:{port}"
        self.session: Optional[aiohttp.ClientSession] = None
        
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
        
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def check_api_health(self) -> Dict[str, Any]:
        """Check if the API is responding"""
        try:
            async with self.session.get(
                f"{self.base_url}/health", 
                timeout=aiohttp.ClientTimeout(total=5)
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "status": "healthy",
                        "response_time": data.get("response_time", 0),
                        "timestamp": data.get("timestamp"),
                        "version": data.get("version")
                    }
                else:
                    return {
                        "status": "unhealthy",
                        "error": f"HTTP {response.status}",
                        "timestamp": datetime.utcnow().isoformat()
                    }
        except asyncio.TimeoutError:
            return {
                "status": "unhealthy",
                "error": "Request timeout",
                "timestamp": datetime.utcnow().isoformat()
            }
        except Exception as e:
            return {
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def check_voice_pipeline(self) -> Dict[str, Any]:
        """Check voice pipeline health"""
        try:
            async with self.session.get(
                f"{self.base_url}/api/voice/status",
                timeout=aiohttp.ClientTimeout(total=5)
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "status": "healthy" if data.get("pipeline_ready") else "degraded",
                        "pipeline_ready": data.get("pipeline_ready", False),
                        "models_loaded": data.get("models_loaded", {}),
                        "timestamp": datetime.utcnow().isoformat()
                    }
                else:
                    return {
                        "status": "unhealthy",
                        "error": f"HTTP {response.status}",
                        "timestamp": datetime.utcnow().isoformat()
                    }
        except Exception as e:
            return {
                "status": "degraded",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def check_sync_status(self) -> Dict[str, Any]:
        """Check sync engine health"""
        try:
            async with self.session.get(
                f"{self.base_url}/api/sync/status",
                timeout=aiohttp.ClientTimeout(total=5)
            ) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "status": "healthy",
                        "connected_devices": data.get("connected_devices", 0),
                        "sync_enabled": data.get("sync_enabled", False),
                        "timestamp": datetime.utcnow().isoformat()
                    }
                else:
                    return {
                        "status": "degraded",
                        "error": f"HTTP {response.status}",
                        "timestamp": datetime.utcnow().isoformat()
                    }
        except Exception as e:
            return {
                "status": "degraded",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    def check_system_resources(self) -> Dict[str, Any]:
        """Check system resource usage"""
        try:
            # Memory usage
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            memory_available_gb = memory.available / (1024**3)
            
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Disk usage
            disk = psutil.disk_usage('/')
            disk_percent = disk.percent
            disk_free_gb = disk.free / (1024**3)
            
            # Determine status based on resource usage
            status = "healthy"
            if memory_percent > 90 or cpu_percent > 90 or disk_percent > 90:
                status = "unhealthy"
            elif memory_percent > 75 or cpu_percent > 75 or disk_percent > 80:
                status = "degraded"
            
            return {
                "status": status,
                "memory": {
                    "percent_used": memory_percent,
                    "available_gb": round(memory_available_gb, 2)
                },
                "cpu": {
                    "percent_used": cpu_percent
                },
                "disk": {
                    "percent_used": disk_percent,
                    "free_gb": round(disk_free_gb, 2)
                },
                "timestamp": datetime.utcnow().isoformat()
            }
        except Exception as e:
            return {
                "status": "unknown",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def comprehensive_health_check(self) -> Dict[str, Any]:
        """Run all health checks"""
        results = {
            "overall_status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {}
        }
        
        # API health check
        api_health = await self.check_api_health()
        results["checks"]["api"] = api_health
        
        # Voice pipeline check
        voice_health = await self.check_voice_pipeline()
        results["checks"]["voice"] = voice_health
        
        # Sync status check
        sync_health = await self.check_sync_status()
        results["checks"]["sync"] = sync_health
        
        # System resources check
        system_health = self.check_system_resources()
        results["checks"]["system"] = system_health
        
        # Determine overall status
        statuses = [check["status"] for check in results["checks"].values()]
        if "unhealthy" in statuses:
            results["overall_status"] = "unhealthy"
        elif "degraded" in statuses:
            results["overall_status"] = "degraded"
        
        return results


async def single_health_check() -> int:
    """Perform a single health check and exit"""
    async with BuddyHealthCheck() as health_checker:
        result = await health_checker.check_api_health()
        
        if result["status"] == "healthy":
            print("✅ BUDDY is healthy")
            return 0
        else:
            print(f"❌ BUDDY is unhealthy: {result.get('error', 'Unknown error')}")
            return 1


async def continuous_monitoring(interval: int = 30):
    """Run continuous health monitoring"""
    async with BuddyHealthCheck() as health_checker:
        print(f"🔍 Starting BUDDY health monitoring (interval: {interval}s)")
        
        while True:
            try:
                result = await health_checker.comprehensive_health_check()
                
                # Log to console
                timestamp = result["timestamp"]
                status = result["overall_status"]
                status_emoji = {
                    "healthy": "✅",
                    "degraded": "⚠️",
                    "unhealthy": "❌"
                }.get(status, "❓")
                
                print(f"{status_emoji} [{timestamp}] Overall status: {status}")
                
                # Log details if not healthy
                if status != "healthy":
                    for check_name, check_result in result["checks"].items():
                        check_status = check_result["status"]
                        if check_status != "healthy":
                            error = check_result.get("error", "No error details")
                            print(f"   {check_name}: {check_status} - {error}")
                
                # Save to file for external monitoring
                log_file = Path("/app/data/logs/health.json")
                log_file.parent.mkdir(parents=True, exist_ok=True)
                
                with open(log_file, "w") as f:
                    json.dump(result, f, indent=2)
                
                await asyncio.sleep(interval)
                
            except KeyboardInterrupt:
                print("\n🛑 Health monitoring stopped")
                break
            except Exception as e:
                print(f"❌ Health monitoring error: {e}")
                await asyncio.sleep(interval)


def main():
    parser = argparse.ArgumentParser(description="BUDDY Health Check")
    parser.add_argument(
        "--monitor", 
        action="store_true", 
        help="Run continuous monitoring"
    )
    parser.add_argument(
        "--interval", 
        type=int, 
        default=30, 
        help="Monitoring interval in seconds"
    )
    parser.add_argument(
        "--host", 
        default="localhost", 
        help="BUDDY host"
    )
    parser.add_argument(
        "--port", 
        type=int, 
        default=8000, 
        help="BUDDY port"
    )
    
    args = parser.parse_args()
    
    if args.monitor:
        # Run continuous monitoring
        try:
            asyncio.run(continuous_monitoring(args.interval))
        except KeyboardInterrupt:
            print("\n👋 Monitoring stopped by user")
    else:
        # Single health check
        exit_code = asyncio.run(single_health_check())
        sys.exit(exit_code)


if __name__ == "__main__":
    main()