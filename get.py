import requests

ids = "%2C".join(['velodrome-finance','usd-coin','dai'])
r=requests.get(f"https://api.coingecko.com/api/v3/simple/price?ids={ids}&vs_currencies=usd")
print(r.json())