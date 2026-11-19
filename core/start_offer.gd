class_name StartOffer
extends RefCounted
## A run's opening-time offer (full build plan 7.2): today's dealt products (the counted aisle
## boosters' cards, StartSetupRules) and how many deals the fair-deal check made (telemetry). A
## run holds it while it waits in CHOOSE_START for OPEN STORE (RunState.open_store), and the run
## save keeps it. The starter packs it offered since #107 were removed in v1.41 (2026-11-18).

## Today's products: the counted boosters' cards.
var shared: Array[CardDefinition] = []
## Deals of the boosters made (1: the first passed, or there is no check).
var deals: int = 1
