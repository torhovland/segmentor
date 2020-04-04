package main

import (
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
)

func main() {
	http.HandleFunc("/exchange_token", tokenHandler)

	fs := http.FileServer(http.Dir("static/"))
	http.Handle("/", fs)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	codes, ok := r.URL.Query()["code"]

	if !ok || len(codes[0]) < 1 {
		http.Error(w, "Url parameter 'code' is missing.", http.StatusBadRequest)
		return
	}

	code := codes[0]

	log.Println("Url parameter 'code' is: " + string(code))

	clientSecret, err := ioutil.ReadFile("strava_client_secret")

	if err != nil {
		http.Error(w, "Strava API is not configured.", http.StatusInternalServerError)
		log.Printf("Error when reading Strava client secret from file: %s\n", err)
		return
	}

	response, err := http.PostForm("https://www.strava.com/oauth/token", url.Values{
		"client_id":     {"38457"},
		"client_secret": {string(clientSecret)},
		"code":          {code},
		"grant_type":    {"authorization_code"},
	})

	if err != nil {
		http.Error(w, "Error when requesting Strava API token.", http.StatusInternalServerError)
		log.Printf("Error when requesting Strava token: %s\n", err)
		return
	}

	defer response.Body.Close()
	bytes, err := ioutil.ReadAll(response.Body)

	if err != nil {
		http.Error(w, "Error when receiving Strava API token.", http.StatusInternalServerError)
		log.Printf("Error when reading Strava token: %s\n", err)
		return
	}

	body := string(bytes)

	if response.StatusCode >= 400 {
		http.Error(w, body, http.StatusInternalServerError)
		log.Printf("Error returned from Strava API: %s\n", body)
		return
	}

	log.Printf("Response from Strava API: %s\n", body)

	cookie := http.Cookie{Name: "strava_response", Value: body}
	http.SetCookie(w, &cookie)

	http.Redirect(w, r, "/", 303)
}
