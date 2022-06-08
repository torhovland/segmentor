export function getActivities() {
    return fetch('http://localhost:8088/activities').then(res =>
        res.json()
    )
}
