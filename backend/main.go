package main

import (
	"fmt"
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
		log.Println("Url Param 'code' is missing")
		return
	}

	code := codes[0]

	log.Println("Url Param 'code' is: " + string(code))

	response, err := http.PostForm("https://www.strava.com/oauth/token", url.Values{
		"client_id":     {"38457"},
		"client_secret": {"foo"},
		"code":          {code},
		"grant_type":    {"authorization_code"},
	})

	if err != nil {
		fmt.Fprintf(w, "Error when requesting Strava token: %s", err)
		return
	}

	defer response.Body.Close()
	body, err := ioutil.ReadAll(response.Body)

	if err != nil {
		fmt.Fprintf(w, "Error when reading Strava token: %s", err)
		return
	}

	log.Println(string(body))

	if response.StatusCode >= 400 {
		fmt.Fprintf(w, "%s", body)
	}
}
