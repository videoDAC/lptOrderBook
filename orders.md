## Approval

You can [use this dApp to approve the lptfutures contract to spend your DAI](https://oneclickdapp.com/diamond-explore/). This is required in order to fill an order.

When using this dApp, you must use the following parameters:

- `guy` = `0xd43FF5612420c8bcc6316DCc15FEDfb4b791df32` (this is the address of the lptfutures contract)
- `wad` = the amount of DAI in the DAI Qty column for the order you would like to fill.

## How it works

`IF` you fill the order by committing the `DAI Qty`

`AND` the seller delivers the `LPT Qty` to you before `"Deliver By" Block`

`THEN` the seller will receive your `DAI Qty`

`ELSE` you can claim back the `DAI Qty` **PLUS** the `DAI Collateral`.

## Order Book

| `Price *` | `"Deliver By" Block` | `LPT Qty` | `DAI Qty` | `DAI Collateral` |                                                     |
|-----------|----------------------|-----------|-----------|------------------|-----------------------------------------------------|
| `0.0000`  | `0000000`            | `0.00`    | `00000`   | `0000`           | [Link](https://oneclickdapp.com/emotion-optic/)     |
| `0.0000`  | `0000000`            | `0.00`    | `00000`   | `0000`           | [Link](https://oneclickdapp.com/joshua-nebula/)     |
| `0.0000`  | `0000000`            | `0.00`    | `00000`   | `0000`           | [Link](https://oneclickdapp.com/village-distant/)   |
| `0.0000`  | `0000000`            | `0.00`    | `00000`   | `0000`           | [Link](https://oneclickdapp.com/dolby-kimono/)      |

`*` Price = DAI ÷ LPT

`†` % Collateral = Collateral ÷ DAI
