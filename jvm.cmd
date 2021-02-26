while true; do tmp=$(cat dummyIn); echo "$tmp"; if [[ "$tmp" == "/stop" ]]; then break; fi; done | java -Xmx3072M -Xms1024M -jar server.jar nogui > dummyOut
