package main

import (
	"fmt"
	"log"
	"net/http"
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
	if r.URL.Path != "/exchange_token" {
		http.NotFound(w, r)
		return
	}
	fmt.Fprint(w, "Hello, Worlds!")
}
