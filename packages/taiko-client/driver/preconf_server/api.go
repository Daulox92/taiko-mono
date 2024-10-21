package preconf_server

import (
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4"
)

type PreconfBlockGroupStatus string

const (
	StatusFinalBlockGroup   PreconfBlockGroupStatus = "finalBlockGroup"
	StatusFinalPreconfGroup PreconfBlockGroupStatus = "finalPreconfGroup"
)

// PreconfTransactionsGroup represents a preconfirmation block group.
type PreconfTransactionsGroup struct {
	BlockID          uint64                  `json:"blockId"`
	ID               uint64                  `json:"groupId"`
	TransactionsList types.Transactions      `json:"transactions"`
	GroupStatus      PreconfBlockGroupStatus `json:"groupStatus"`
	Signature        string                  `json:"signature"`

	// Block parameters
	Timestamp             uint64         `json:"timestamp"`
	Random                common.Hash    `json:"prevRandao"`
	SuggestedFeeRecipient common.Address `json:"suggestedFeeRecipient"`
	BaseFeePerGas         uint64         `json:"baseFeePerGas"`
}

// CreateBlocksByGroupsRequestBody represents a request body when handling preconfirmation blocks creation requests.
type CreateBlocksByGroupsRequestBody struct {
	TransactionsGroups []PreconfTransactionsGroup `json:"transactionsGroups"`
}

// CreateBlocksByGroupsResponseBody represents a response body when handling preconfirmation blocks creation requests.
type CreateBlocksByGroupsResponseBody struct {
	PreconfHeaders []types.Header `json:"preconfHeaders"`
}

// CreateBlocksByGroups handles a preconfirmation blocks creation request,
// if the preconfirmation block groups in request are valid, it will insert the correspoinding new preconfirmation
// blocks to the backend L2 execution engine and return a success response.
//
//	@Summary	  Insert preconfirmation blocks by the given groups to the backend L2 execution engine, please note that
//	            the AVS service should sort the groups and make sure all the groups are valid at first.
//	@Param      body body CreateBlocksByGroupsRequestBody true "preconf blocks creation request body"
//	@Accept			json
//	@Produce		json
//	@Success		200		{object} CreateBlocksByGroupsResponseBody
//	@Router			/perconfBlocks [post]
func (s *PreconfAPIServer) CreateBlocksByGroups(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// ResetPreconfHeadRequestBody represents a request body when resetting the backend
// L2 execution engine preconfirmation head.
type ResetPreconfHeadRequestBody struct {
	NewHead uint64 `json:"newHead"`
}

// ResetPreconfHeadResponseBody represents a response body when resetting the backend
// L2 execution engine preconfirmation head.
type ResetPreconfHeadResponseBody struct {
	CurrentHead types.Header `json:"currentHead"`
}

// ResetPreconfHead resets the backend L2 execution engine preconfirmation head.
//
//	@Summary	  Resets the backend L2 execution engine preconfirmation head, please note that
//	            the AVS service should make sure the new head height is from a valid preconfirmation head.
//	@Param      body body ResetPreconfHeadRequestBody true "preconf blocks creation request body"
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} ResetPreconfHeadResponseBody
//	@Router			/preconfHead [put]
func (s *PreconfAPIServer) ResetPreconfHead(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// HealthCheck is the endpoints for probes.
//
//	@Summary		Get current server health status
//	@ID			   	health-check
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} Status
//	@Router			/healthz [get]
func (s *PreconfAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}