package main

import (
	"crypto/tls"
	"fmt"
	"log"
	"strings"
)

var Target = "example.com:443"

func main() {
	conf := &tls.Config{
		InsecureSkipVerify: true,
		ClientSessionCache: tls.NewLRUClientSessionCache(32),
	}

	conn, err := tls.Dial("tcp", Target, conf)
	if err != nil {
		log.Fatalln("Failed to connect:", err)
	}
	conn.Close()

	conn, err = tls.Dial("tcp", Target, conf)
	if err != nil && strings.Contains(err.Error(), "unexpected message") {
		fmt.Println(Target, "is vulnerable to Ticketbleed")
	} else if err != nil {
		log.Fatalln("Failed to reconnect:", err)
	} else {
		fmt.Println(Target, "does NOT appear to be vulnerable")
		conn.Close()
	}
}
