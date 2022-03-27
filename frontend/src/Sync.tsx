import { useEffect, useState } from "react";
import { useBaseName, useEnvironment } from "./hooks";

type SyncState = "Idle" | "Syncing" | "Complete";

export default function Sync() {
    const environment = useEnvironment();
    const baseName = useBaseName();
    const [count, setCount] = useState(0);
    const [syncState, setSyncState] = useState("Idle" as SyncState);
    const socketUrl = `${environment === "Development" ? "ws" : "wss"}://${baseName}/sync`;
    let socket = null;

    useEffect(() => {
        let i = count;

        if (syncState === "Idle") {
            console.log("Initialising web socket.");
            setSyncState("Syncing");
            socket = new WebSocket(socketUrl);

            socket.onmessage = function (event) {
                console.log(event.data);
                i++;
                setCount(i);
                if (i >= 3) setSyncState("Complete");
            }
        }
    });

    return <section>Count: {count}</section>
}
