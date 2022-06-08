import { useQuery, useQueryClient } from "react-query";
import { getActivities } from './api'

type Activity = {
    id: number
    name: String
}

export default function Activities() {
    const { isLoading, error, data } = useQuery('activities', getActivities)

    if (isLoading) return <>Loading...</>

    if (error) return <>An error has occurred.</>

    return <section>
        <h1>Activities</h1>
        <ul>
            {data.map((activity: Activity) => (
                <li key={activity.id}>{activity.name}</li>
            ))}
        </ul>
    </section>
}
