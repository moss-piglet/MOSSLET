import MossletFrameworkHooks from "../../_mosslet_framework/js/hooks";
import CharacterCounter from "./character-counter";
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
import HideNestedReplyComposer from "./hide-nested-reply-composer";
import TippyHook from "./tippy-hook";
import TrixEditor from "./trix";
import TrixContentPostHook from "./trix-content-post-hook";
import TrixContentReplyHook from "./trix-content-reply-hook";
import { ContentWarningHook } from "./content-warning-hook";
import ScrollDown from "./scroll";
import RestoreBodyScroll from "./restore-body-scroll";

export default {
  CharacterCounter,
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
  RestoreBodyScroll,
  HideNestedReplyComposer,
  ScrollDown,
  TippyHook,
  TrixEditor,
  TrixContentPostHook,
  TrixContentReplyHook,
  ContentWarningHook,
};
