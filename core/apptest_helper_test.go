package core

import (
	"io"
	"net/http"
)

// newAppTestRequest builds a relative-URL request for fiber's app.Test.
// Newer fasthttp rejects requests without a Host header, so set one.
func newAppTestRequest(method, target string, body io.Reader) (*http.Request, error) {
	req, err := http.NewRequest(method, target, body)
	if err != nil {
		return nil, err
	}
	req.Host = "localhost"
	return req, nil
}
