import MossletFrameworkHooks from "../../_mosslet_framework/js/hooks";
import AccountRecoveryHook from "./account-recovery-hook";
import AutoResize from "./auto-resize";
import BookmarkNoteHook from "./bookmark-note-hook";
import BookScrollReader from "./book-scroll-reader";
import ConversationEmojiPicker from "./conversation-emoji-picker";
import { ConversationComposer, DecryptMessage, ConversationScroll } from "./conversation-hooks";
import DecryptGroupMessage from "./decrypt-group-message";
import DecryptGroupMetadata from "./decrypt-group-metadata";
import DecryptJournalEntry from "./decrypt-journal-entry";
import DecryptAvatar from "./decrypt-avatar";
import DecryptBookmarkNote from "./decrypt-bookmark-note";
import DecryptConnectionCard from "./decrypt-connection-card";
import DecryptInviterName from "./decrypt-inviter-name";
import DecryptPost from "./decrypt-post";
import DecryptProfileFields from "./decrypt-profile-fields";
import DecryptReply from "./decrypt-reply";
import DecryptStatusMessage from "./decrypt-status-message";
import EncryptUpload from "./encrypt-upload";
import ExtractedEntryFormHook from "./extracted-entry-form-hook";
import NsfwCheck from "./nsfw-check";
import DecryptUserFields from "./decrypt-user-fields";
import PostFormHook from "./post-form-hook";
import ProfileFieldsFormHook from "./profile-fields-form-hook";
import CharacterCounter from "./character-counter";
import ClipboardHook from "./clipboard-hook";
import ComposerEmojiPicker from "./composer-emoji-picker";
import CSSBookBackCoverClick from "./css-book-back-cover-click";
import CSSBookCoverClick from "./css-book-cover-click";
import EntryColumnFlow from "./entry-column-flow";
import GroupMessageEmojiPicker from "./group-message-emoji-picker";
import GroupMessageEditFormHook from "./group-message-edit-form-hook";
import GroupMessageFormHook from "./group-message-form-hook";
import GroupMetadataFormHook from "./group-metadata-form-hook";
import ClearFlashHook from "./clear-flash-hook";
import LiquidFlash from "./liquid-flash";
import LoginHook from "./login-hook";
import FlashGroup from "./flash-group";
import InfiniteScrollGroupMessage from "./infinite-scroll-group-message";
import * as LocalTimeHooks from "./local-time-hooks";
import { LocalTimeTooltip } from "./local-time-tooltip";
import LockBodyScroll from "./lock-body-scroll";
import Menu from "./dropdown-menu";
import MentionHighlight from "./mention-highlight";
import MentionPicker from "./mention-picker";
import MessageReactions from "./message-reactions";
import RegistrationHook from "./registration-hook";
import RecoveryKeySetupHook from "./recovery-key-setup-hook";
import ReplyComposer from "./reply-composer";
import ReplyEmojiPicker from "./reply-emoji-picker";
import ReplyFormHook from "./reply-form-hook";
import RepostFormHook from "./repost-form-hook";
import TippyHook from "./tippy-hook";
import UnlockHook from "./unlock-hook";
import TrixContentPostHook from "./trix-content-post-hook";
import TrixContentReplyHook from "./trix-content-reply-hook";
import ScrollDown from "./scroll";
import RestoreBodyScroll from "./restore-body-scroll";
import ImageDownloadHook from "./image-download-hook";
import DisableContextMenu from "./disable-context-menu";
import ImageModalHook from "./image-modal-hook";
import StatusIndicatorHook from "./status-indicator-hook";
import URLPreviewHook from "./url-preview-hook";
import ScrollableTabs from "./scrollable-tabs";
import TouchHoverHook from "./touch-hover-hook";
import PublicPostImagesHook from "./public-post-images-hook";
import ImageErrorHook from "./image-error-hook";
import ImageLightbox from "./image-lightbox-hook";
import UnsavedChanges from "./unsaved-changes";
import SortableUploadsHook from "./sortable-uploads-hook";
import StatusFormHook from "./status-form-hook";
import ShareNoteFormHook from "./share-note-form-hook";
import SortableBooksHook from "./sortable-books-hook";
import ImageResizeUploadHook from "./image-resize-upload-hook";
import ImageCropHook from "./image-crop-hook";
import JournalBookFormHook from "./journal-book-form-hook";
import JournalDragDropHook from "./journal-drag-drop-hook";
import JournalEntryFormHook from "./journal-entry-form-hook";
import WordCounter from "./word-counter";
import SessionKeyDeriver from "./session-key-deriver";
import SyncStatusHook from "./sync-status-hook";
import BlockReasonFormHook from "./block-reason-form-hook";
import PlatformDetector from "./platform-detector";
import PostExpandHook from "./post-expand-hook";
import ProfileAboutFormHook from "./profile-about-form-hook";
import ConnectionFormHook from "./connection-form-hook";
import ConnectionLabelFormHook from "./connection-label-form-hook";
import VisibilityGroupFormHook from "./visibility-group-form-hook";
import ConversationTouchReveal from "./conversation-touch-reveal";
import StartConversation from "./start-conversation";
import ZkExportHook from "./zk-export-hook";
import ZkMoodInsights from "./zk-mood-insights";

export default {
  AccountRecoveryHook,
  AutoResize,
  BookmarkNoteHook,
  BookScrollReader,
  CharacterCounter,
  ClipboardHook,
  ComposerEmojiPicker,
  ConversationComposer,
  ConnectionFormHook,
  ConnectionLabelFormHook,
  VisibilityGroupFormHook,
  ConversationEmojiPicker,
  ConversationScroll,
  ConversationTouchReveal,
  CSSBookBackCoverClick,
  CSSBookCoverClick,
  DecryptAvatar,
  DecryptBookmarkNote,
  DecryptConnectionCard,
  DecryptInviterName,
  DecryptGroupMessage,
  DecryptGroupMetadata,
  DecryptJournalEntry,
  DecryptMessage,
  DecryptPost,
  DecryptProfileFields,
  DecryptReply,
  DecryptStatusMessage,
  DecryptUserFields,
  EncryptUpload,
  EntryColumnFlow,
  ExtractedEntryFormHook,
  GroupMessageEmojiPicker,
  GroupMessageEditFormHook,
  GroupMessageFormHook,
  GroupMetadataFormHook,
  ClearFlashHook,
  LiquidFlash,
  FlashGroup,
  InfiniteScrollGroupMessage,
  ...LocalTimeHooks,
  LocalTimeTooltip,
  LockBodyScroll,
  LoginHook,
  Menu,
  MentionHighlight,
  MentionPicker,
  MessageReactions,
  MossletFrameworkHooks,
  NsfwCheck,
  PostFormHook,
  ProfileAboutFormHook,
  ProfileFieldsFormHook,
  RecoveryKeySetupHook,
  RegistrationHook,
  ReplyComposer,
  ReplyEmojiPicker,
  ReplyFormHook,
  RepostFormHook,
  RestoreBodyScroll,
  ScrollableTabs,
  ScrollDown,
  SessionKeyDeriver,
  ShareNoteFormHook,
  TippyHook,
  TrixContentPostHook,
  TrixContentReplyHook,
  UnlockHook,
  ImageDownloadHook,
  DisableContextMenu,
  ImageModalHook,
  StatusIndicatorHook,
  TouchHoverHook,
  URLPreviewHook,
  PublicPostImagesHook,
  ImageErrorHook,
  ImageLightbox,
  UnsavedChanges,
  SortableUploadsHook,
  StatusFormHook,
  SortableBooksHook,
  ImageResizeUploadHook,
  ImageCropHook,
  JournalBookFormHook,
  JournalDragDropHook,
  JournalEntryFormHook,
  WordCounter,
  SyncStatusHook,
  BlockReasonFormHook,
  PlatformDetector,
  PostExpandHook,
  StartConversation,
  ZkExportHook,
  ZkMoodInsights,
};
