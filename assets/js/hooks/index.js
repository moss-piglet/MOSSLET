import MossletFrameworkHooks from "../../_mosslet_framework/js/hooks";
import CharacterCounter from "./character-counter";
import ClipboardHook from "./clipboard-hook";
import ComposerEmojiPicker from "./composer-emoji-picker";
import KeywordFilterInput from "./keyword-filter-input";
import ClearFlashHook from "./clear-flash-hook";
import Flash from "./flash";
import LiquidFlash from "./liquid-flash";
import FlashGroup from "./flash-group";
import HoverRemark from "./hover-remark";
import HoverGroupMessage from "./hover-group-message";
import InfiniteScrollGroupMessage from "./infinite-scroll-group-message";
import InfiniteScrollRemark from "./infinite-scroll-remark";
import * as LocalTimeHooks from "./local-time-hooks";
import { LocalTimeTooltip } from "./local-time-tooltip";
import MaintainFocus from "./maintain-focus";
import Menu from "./dropdown-menu";
import ModalPortal from "./modal-portal";
import ReplyComposer from "./reply-composer";
import ReplyEmojiPicker from "./reply-emoji-picker";
import TippyHook from "./tippy-hook";
import TrixEditor from "./trix";
import TrixContentPostHook from "./trix-content-post-hook";
import TrixContentReplyHook from "./trix-content-reply-hook";
import { ContentWarningHook } from "./content-warning-hook";
import ScrollDown from "./scroll";
import RestoreBodyScroll from "./restore-body-scroll";
import ImageDownloadHook from "./image-download-hook";
import DisableContextMenu from "./disable-context-menu";
import ImageModalHook from "./image-modal-hook";
import StatusIndicatorHook from "./status-indicator-hook";
import URLPreviewHook from "./url-preview-hook";
import ScrollableTabs from "./scrollable-tabs";

export default {
  CharacterCounter,
  ClipboardHook,
  ComposerEmojiPicker,
  KeywordFilterInput,
  ClearFlashHook,
  Flash,
  LiquidFlash,
  FlashGroup,
  HoverGroupMessage,
  HoverRemark,
  InfiniteScrollGroupMessage,
  InfiniteScrollRemark,
  ...LocalTimeHooks,
  LocalTimeTooltip,
  MaintainFocus,
  Menu,
  ModalPortal,
  MossletFrameworkHooks,
  ReplyComposer,
  ReplyEmojiPicker,
  RestoreBodyScroll,
  ScrollableTabs,
  ScrollDown,
  TippyHook,
  TrixEditor,
  TrixContentPostHook,
  TrixContentReplyHook,
  ContentWarningHook,
  ImageDownloadHook,
  DisableContextMenu,
  ImageModalHook,
  StatusIndicatorHook,
  URLPreviewHook,
};
