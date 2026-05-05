package appwrite

import (
	"net/url"
	"strconv"
)

func withPagedQueries(path string, limit, offset int) string {
	parsed, err := url.Parse(path)
	if err != nil {
		return path
	}

	values := parsed.Query()
	values.Add("queries[]", appwriteQueryJSON("limit", limit))
	values.Add("queries[]", appwriteQueryJSON("offset", offset))
	parsed.RawQuery = values.Encode()
	return parsed.String()
}

func appwriteQueryJSON(method string, value int) string {
	return `{"method":"` + method + `","values":[` + strconv.Itoa(value) + `]}`
}
