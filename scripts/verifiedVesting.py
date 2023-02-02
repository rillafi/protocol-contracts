import os
import pandas as pd
from web3 import Web3
import json
from dotenv import load_dotenv
import math

load_dotenv()


def main():
    # init
    w3 = Web3(
        Web3.HTTPProvider(
            "https://opt-mainnet.g.alchemy.com/v2/"
            + os.environ.get("ALCHEMY_KEY_OPTIMISM")
        )
    )
    vestingAddress = ""
    abi = ""
    with open("../artifacts/contracts/vesting/TokenVesting.sol/TokenVesting.json") as f:
        js = json.load(f)
        abi = json.dumps(js["abi"])
    contract = w3.eth.contract(address=vestingAddress, abi=abi)

    df = pd.read_csv("VestingTable.csv")
    d = {"Name": [], "Tokens": [], "Address": []}
    for i, ele in df.iterrows():
        name = ele["Name"].strip()
        try:
            idx = d["Name"].index(name)
            d["Tokens"][idx] += int(ele["Tokens"].replace(",", ""))
        except:
            d["Name"].append(ele["Name"])
            d["Tokens"].append(int(ele["Tokens"].replace(",", "")))
            d["Address"].append(
                ele["Address"] if ele["Address"] is not float("nan") else None
            )

    df = pd.DataFrame(d)
    df["Vesting"] = [0] * len(df)
    for i, ele in df.iterrows():
        address = ele["Address"]
        if not pd.isna(address):  # if the value is legit
            id = contract.functions.computeVestingScheduleIdForAddressAndIndex(
                address, 0
            ).call()
            schedule = contract.functions.getVestingSchedule(id).call()
            print(schedule)
            schedule['amountTotal']


if __name__ == "__main__":
    main()
