#!/usr/bin/env python3
"""
WorkBuddy / OpenClaw 连接测试工具
===================================
用于验证本地 WorkBuddy 服务是否可达，并测试 API 接口。

使用方法:
    python3 test_workbuddy.py
    python3 test_workbuddy.py --token YOUR_TOKEN
    python3 test_workbuddy.py --url http://127.0.0.1:18789 --token YOUR_TOKEN
"""

import asyncio
import argparse
import json
import sys
import httpx

# WorkBuddy/OpenClaw 默认配置（来自官方文档）
DEFAULT_URL   = "http://127.0.0.1:18789"
DEFAULT_TOKEN = ""
SCAN_PORTS    = [18789, 18790, 3000, 4000, 8080, 11434]


async def scan_ports() -> dict:
    """扫描本地端口，找到 WorkBuddy/OpenClaw 实际运行端口"""
    print("\n🔍 扫描本地端口...")
    results = {}
    async with httpx.AsyncClient(timeout=1.5) as client:
        for port in SCAN_PORTS:
            url = f"http://127.0.0.1:{port}"
            try:
                r = await client.get(f"{url}/")
                results[port] = {"reachable": True, "status": r.status_code, "url": url}
                print(f"  ✅ 端口 {port}: HTTP {r.status_code}")
            except httpx.ConnectError:
                results[port] = {"reachable": False, "error": "Connection refused"}
                print(f"  ❌ 端口 {port}: 未运行")
            except Exception as e:
                results[port] = {"reachable": False, "error": str(e)}
                print(f"  ⚠️  端口 {port}: {type(e).__name__}")
    return results


async def test_health(base_url: str, token: str) -> bool:
    """测试 /health 端点"""
    print(f"\n🏥 测试健康检查: {base_url}/health")
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{base_url}/health", headers=headers)
            print(f"  状态码: {r.status_code}")
            try:
                data = r.json()
                print(f"  响应: {json.dumps(data, ensure_ascii=False, indent=2)}")
            except Exception:
                print(f"  响应: {r.text[:200]}")
            return r.status_code < 500
    except httpx.ConnectError:
        print(f"  ❌ 连接失败: {base_url} 未运行")
        return False
    except Exception as e:
        print(f"  ❌ 错误: {e}")
        return False


async def test_models(base_url: str, token: str) -> bool:
    """测试 /v1/models 端点"""
    print(f"\n📋 测试模型列表: {base_url}/v1/models")
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{base_url}/v1/models", headers=headers)
            print(f"  状态码: {r.status_code}")
            try:
                data = r.json()
                models = data.get("data", [])
                print(f"  可用模型数量: {len(models)}")
                for m in models[:5]:
                    print(f"    - {m.get('id', 'unknown')}")
            except Exception:
                print(f"  响应: {r.text[:300]}")
            return r.status_code == 200
    except httpx.ConnectError:
        print(f"  ❌ 连接失败")
        return False
    except Exception as e:
        print(f"  ❌ 错误: {e}")
        return False


async def test_chat(base_url: str, token: str, agent_id: str = "main") -> bool:
    """测试 /v1/chat/completions 端点（WorkBuddy/OpenClaw 核心接口）"""
    print(f"\n💬 测试聊天接口: {base_url}/v1/chat/completions")
    print(f"   Agent ID: {agent_id}")
    
    if not token:
        print("  ⚠️  未提供 token，跳过聊天测试")
        print("  提示: 在 WorkBuddy 设置 → API → 生成 Gateway Token")
        return False
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "x-openclaw-agent-id": agent_id,
    }
    
    # WorkBuddy/OpenClaw 的 model 格式: "openclaw:<agentId>"
    payload = {
        "model": f"openclaw:{agent_id}",
        "messages": [{"role": "user", "content": "你好，请回复'连接成功'"}],
        "max_tokens": 50,
        "stream": False,
    }
    
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(
                f"{base_url}/v1/chat/completions",
                headers=headers,
                json=payload,
            )
            print(f"  状态码: {r.status_code}")
            try:
                data = r.json()
                if r.status_code == 200:
                    choices = data.get("choices", [])
                    if choices:
                        content = choices[0].get("message", {}).get("content", "")
                        print(f"  ✅ 响应内容: {content[:100]}")
                        return True
                    else:
                        print(f"  ⚠️  响应格式异常: {json.dumps(data, ensure_ascii=False)[:200]}")
                else:
                    print(f"  ❌ 错误响应: {json.dumps(data, ensure_ascii=False)[:300]}")
            except Exception:
                print(f"  响应: {r.text[:300]}")
            return r.status_code == 200
    except httpx.ConnectError:
        print(f"  ❌ 连接失败: WorkBuddy 未运行或端口不正确")
        return False
    except httpx.TimeoutException:
        print(f"  ⏰ 超时: WorkBuddy 响应过慢")
        return False
    except Exception as e:
        print(f"  ❌ 错误: {e}")
        return False


async def test_proxy_integration(proxy_url: str = "http://localhost:8082") -> bool:
    """测试本地代理服务器是否运行"""
    print(f"\n🔗 测试代理服务器: {proxy_url}")
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"{proxy_url}/health")
            if r.status_code == 200:
                data = r.json()
                print(f"  ✅ 代理服务器运行中")
                print(f"  当前 Provider: {data.get('provider', 'unknown')}")
                return True
    except Exception:
        pass
    print(f"  ❌ 代理服务器未运行，请先执行: python3 server.py")
    return False


async def main():
    parser = argparse.ArgumentParser(description="WorkBuddy/OpenClaw 连接测试工具")
    parser.add_argument("--url",   default=DEFAULT_URL,   help=f"WorkBuddy URL (默认: {DEFAULT_URL})")
    parser.add_argument("--token", default=DEFAULT_TOKEN, help="WorkBuddy Gateway Token")
    parser.add_argument("--agent", default="main",        help="Agent ID (默认: main)")
    parser.add_argument("--scan",  action="store_true",   help="仅扫描端口")
    args = parser.parse_args()

    print("=" * 60)
    print("  WorkBuddy / OpenClaw 连接测试工具")
    print("=" * 60)
    print(f"  目标 URL : {args.url}")
    print(f"  Token    : {'已设置' if args.token else '未设置（聊天测试将跳过）'}")
    print(f"  Agent ID : {args.agent}")

    # 1. 端口扫描
    port_results = await scan_ports()
    reachable = [p for p, v in port_results.items() if v.get("reachable")]
    
    if args.scan:
        print(f"\n可达端口: {reachable}")
        return
    
    # 2. 测试代理服务器
    await test_proxy_integration()
    
    # 3. 测试 WorkBuddy
    health_ok = await test_health(args.url, args.token)
    models_ok = await test_models(args.url, args.token)
    chat_ok   = await test_chat(args.url, args.token, args.agent)
    
    # 汇总
    print("\n" + "=" * 60)
    print("  测试结果汇总")
    print("=" * 60)
    print(f"  端口扫描  : {'✅ 发现可达端口 ' + str(reachable) if reachable else '❌ 未发现运行中的服务'}")
    print(f"  健康检查  : {'✅ 通过' if health_ok else '❌ 失败'}")
    print(f"  模型列表  : {'✅ 通过' if models_ok else '❌ 失败'}")
    print(f"  聊天接口  : {'✅ 通过' if chat_ok else '❌ 失败（需要 token）' if not args.token else '❌ 失败'}")
    
    if not reachable or (not health_ok and not models_ok):
        print("\n⚠️  WorkBuddy 未运行，请检查：")
        print("  1. 打开 WorkBuddy 桌面应用")
        print("  2. 确保 Gateway 功能已启用（设置 → API → 启用 Gateway）")
        print("  3. 默认端口为 18789，如果修改过请用 --url 参数指定")
        print("  4. 获取 Gateway Token: 设置 → API → 生成 Gateway Token")
        print("\n  然后在 .env 文件中设置:")
        print("  PREFERRED_PROVIDER=workbuddy")
        print("  WORKBUDDY_BASE_URL=http://127.0.0.1:18789")
        print("  WORKBUDDY_GATEWAY_TOKEN=your_token_here")
    elif not chat_ok and not args.token:
        print("\n💡 WorkBuddy 已运行！要测试聊天功能，请提供 token:")
        print(f"  python3 test_workbuddy.py --token YOUR_TOKEN")
    else:
        print("\n✅ WorkBuddy 集成测试完成！")


if __name__ == "__main__":
    asyncio.run(main())
