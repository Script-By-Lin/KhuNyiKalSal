import asyncio
import httpx

async def test():
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://khunyikalsal-production.up.railway.app/api/auth/login",
            json={"email": "admin@khunyikalsal.com", "password": "admin123456"}
        )
        if resp.status_code == 200:
            token = resp.json().get("access_token")
            headers = {"Authorization": f"Bearer {token}"}
            
            orgs_resp = await client.get(
                "https://khunyikalsal-production.up.railway.app/api/admin/organizations",
                headers=headers
            )
            
            if orgs_resp.status_code == 200:
                orgs = orgs_resp.json()
                if orgs:
                    # Let's delete the first one!
                    org_id = orgs[0]['account_id']
                    del_resp = await client.delete(
                        f"https://khunyikalsal-production.up.railway.app/api/admin/organizations/{org_id}",
                        headers=headers
                    )
                    print("Delete:", del_resp.status_code, del_resp.text)

asyncio.run(test())
