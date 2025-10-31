package media

import (
	"context"
	"errors"
	"regexp"
)

type Service struct {
	Repo Repo
}

func NewService(r Repo) *Service { return &Service{Repo: r} }

var reUC = regexp.MustCompile(`^UC[0-9A-Za-z_-]+$`)

type CreateChannelPayload struct {
	Source      string  `json:"source"`
	ChannelID   string  `json:"channel_id"`
	DisplayName *string `json:"display_name,omitempty"`
	URL         *string `json:"url,omitempty"`
}

func (s *Service) CreateOrUpsertChannel(ctx context.Context, p CreateChannelPayload, createdBy *string) (*MediaChannel, error) {
	if p.Source != SourceYouTube {
		return nil, errors.New(ErrCodeBadInput)
	}
	if !reUC.MatchString(p.ChannelID) {
		return nil, errors.New(ErrCodeBadInput)
	}
	ch := &MediaChannel{
		Source:      p.Source,
		ChannelID:   p.ChannelID,
		DisplayName: p.DisplayName,
		URL:         p.URL,
		CreatedBy:   createdBy,
	}
	out, _, err := s.Repo.UpsertChannel(ctx, ch) // repo คืน (obj, createdNew, err) → ทิ้ง createdNew
	return out, err
}

func (s *Service) GetChannel(ctx context.Context, source, channelID string) (*MediaChannel, error) {
	return s.Repo.GetChannelBySourceAndID(ctx, source, channelID)
}

func (s *Service) DeleteChannel(ctx context.Context, channelUUID string) error {
	return s.Repo.DeleteChannel(ctx, channelUUID)
}

type SubscribePayload struct {
	ChannelUUID string `json:"channel_uuid"`
	Notify      *bool  `json:"notify"`
}

func (s *Service) Subscribe(ctx context.Context, watchID string, p SubscribePayload) (*WatchMediaSubscription, error) {
	notify := true
	if p.Notify != nil {
		notify = *p.Notify
	}
	out, _, err := s.Repo.Subscribe(ctx, watchID, p.ChannelUUID, notify) // ทิ้ง createdNew
	return out, err
}

func (s *Service) ListWatchChannels(ctx context.Context, watchID string) ([]WatchMediaSubscription, error) {
	return s.Repo.ListSubscriptions(ctx, watchID)
}

func (s *Service) Unsubscribe(ctx context.Context, watchID, channelUUID string) error {
	return s.Repo.Unsubscribe(ctx, watchID, channelUUID)
}

func (s *Service) ListMedia(ctx context.Context, watchID string, limit int, cursor *string) ([]MediaPost, *string, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	return s.Repo.ListMediaByWatch(ctx, watchID, limit, cursor)
}
