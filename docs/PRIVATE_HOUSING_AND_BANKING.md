# Private Housing and Banking

The Adventure world now includes an owner-scoped private residence and the
Stillpoint Bank property office. Mutable ownership never lives in authored
house resources: `PropertyBankService` owns the deed and accounts for the
stable principal `base:player/main`, while `HouseDefinition` resources provide
the selectable plans, construction cost, assessed value, and storage capacity.

## Play loop

- The farmhouse door is on the Farmland. Interact to enter the private interior.
- The household chest transfers selected backpack stacks into private home storage.
- Stillpoint Bank is southwest of the town plaza. Its counter opens the private
  vault, wallet/bank transfers, and deed controls.
- Storage transfers are transactional. A full destination leaves the source
  stack unchanged.
- The residence, both stores, wallet, bank balance, compensation, and owner
  principal round-trip through Save v4 `global_world.property_banking`.

## Prolonged absence

The default inactivity term is 30 real-world days, measured from the last
successful capture of `global_world`. On Continue after that term:

1. every item in home storage is atomically transferred to bank custody;
2. the active deed becomes repossessed;
3. the house's authored assessed value is credited to the bank account;
4. a player previously saved inside the home is returned to Stillpoint Town.

Reclamation does not proceed if the complete household inventory cannot be
placed in custody. The bank vault has 120 slots, greater than every available
home plan.

## Return choices

At the bank the player can buy back the previous deed at its assessed value, or
construct one of the available plans:

| Plan | Construction | Assessment | Home slots |
| --- | ---: | ---: | ---: |
| Stillpoint Farmhouse | 1,800 | 2,500 | 48 |
| Willow Courtyard House | 2,200 | 2,700 | 60 |
| Merchant Townhouse | 2,500 | 3,000 | 72 |

Items held in the bank remain there after buyback or reconstruction until the
player explicitly withdraws them. Closing the storage menu with Escape restores
the previous pause and player-input state.
