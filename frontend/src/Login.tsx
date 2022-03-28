import { getCookie } from "./cookies";

export default function Login() {
    const name = getCookie("segmentor-name");

    return <section>{name ? <>Hi, {name}!</> : <>Log in with <a href="/login">Strava</a>.</>}</section>
}
