type CookieName = "segmentor-access-token" | "segmentor-refresh-token" | "segmentor-expires-in" | "segmentor-name" | "segmentor-user-id"

export function getCookie(cname: CookieName) {
    let name = cname + "=";
    let decodedCookie = decodeURIComponent(document.cookie);
    let ca = decodedCookie.split(';');
    for (let i = 0; i < ca.length; i++) {
        let c = ca[i];
        while (c.charAt(0) == ' ') {
            c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
            return c.substring(name.length, c.length);
        }
    }
    return "";
}