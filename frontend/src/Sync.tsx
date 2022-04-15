import { useEffect, useState } from "react";
import { getCookie } from "./cookies";
import { useBaseName, useEnvironment } from "./hooks";

type SyncState = "Idle" | "Syncing" | "Complete";

type SocketMessage = {
    Error?: string;
    Foo?: string;
}

type SocketEvent = {
    data: string;
}

export default function Sync() {
    const environment = useEnvironment();
    const baseName = useBaseName();
    const [count, setCount] = useState(0);
    const [error, setError] = useState(undefined as string | undefined);
    const [syncState, setSyncState] = useState("Idle" as SyncState);
    const socketUrl = `${environment === "Development" ? "ws" : "wss"}://${baseName}/sync`;
    let socket: WebSocket | null = null;

    let getMessage = (event: SocketEvent) => JSON.parse(event.data) as SocketMessage;
    let isError = (message: SocketMessage) => message.Error?.length ?? 0 > 0;
    let isFoo = (message: SocketMessage) => message.Foo?.length ?? 0 > 0;

    useEffect(() => {
        let i = count;

        if (syncState === "Idle") {
            console.log("Initialising web socket.");
            setSyncState("Syncing");
            socket = new WebSocket(socketUrl);

            socket.onopen = (event) => {
                console.log(event);
                socket!.send(getCookie("segmentor-expires-at"));
                socket!.send(getCookie("segmentor-access-token"));
                socket!.send(getCookie("segmentor-refresh-token"));
            };

            socket.onmessage = (event: SocketEvent) => {
                let message = getMessage(event);

                if (isError(message))
                    setError(message.Error);
                else if (isFoo(message)) {
                    console.log(message.Foo);
                    i++;
                    setCount(i);
                    if (i >= 3) setSyncState("Complete");
                }
                else
                    setError(`Unsupported message from backend: ${message}`);
            };
        }
    });

    return <>
        {error && <section>Error: {error}</section>}
        <section>Count: {count}</section>
    </>;
}
