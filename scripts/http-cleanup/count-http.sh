#!/bin/bash
export BW_PASSWORD='dysyN4NxYHMWaMs'
SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)
bw list items --session "$SESSION" 2>/dev/null | jq '[.[] | select(.type == 1) | select(.login.uris != null) | select(.login.uris | any(.uri | startswith("http://")))] | length'
bw lock
