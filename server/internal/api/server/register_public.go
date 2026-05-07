package server

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"

	"go_macos_todo/server/internal/api/contracts"
)

type helloOutput struct {
	ContentType string `header:"Content-Type"`
	Body        []byte
}

type meInput struct {
	Authorization string `header:"Authorization"`
}

type meOutput struct {
	Body contracts.MeResponse
}

const publicTag = "public"

func registerPublic(api huma.API, deps Dependencies) {
	huma.Register(api, huma.Operation{
		OperationID: "getHello",
		Method:      http.MethodGet,
		Path:        "/hello",
		Summary:     "Returns hello world text",
		Tags:        []string{publicTag},
		Responses: map[string]*huma.Response{
			"200": {
				Description: "Plain text hello message",
				Content: map[string]*huma.MediaType{
					"text/plain": {
						Schema: &huma.Schema{Type: huma.TypeString},
					},
				},
			},
		},
	}, func(ctx context.Context, _ *struct{}) (*helloOutput, error) {
		return &helloOutput{ContentType: "text/plain", Body: []byte("hello world\n")}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getMe",
		Method:      http.MethodGet,
		Path:        "/me",
		Summary:     "Returns the authenticated user identity",
		Tags:        []string{publicTag},
		Security:    []map[string][]string{{"bearerAuth": []string{}}},
	}, func(ctx context.Context, input *meInput) (*meOutput, error) {
		identity, err := requireVerifiedIdentity(ctx, deps, input.Authorization)
		if err != nil {
			return nil, err
		}

		return &meOutput{Body: contracts.MeResponse{UserID: identity.UserID, Email: identity.Email}}, nil
	})
}
