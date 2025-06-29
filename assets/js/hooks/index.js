import MossletFrameworkHooks from "../../_mosslet_framework/js/hooks";
import ClearFlashHook from "./clear-flash-hook";
import ColorSchemeHook from "./color-scheme-hook";
import Flash from "./flash";
import HoverRemark from "./hover-remark";
import HoverGroupMessage from "./hover-group-message";
import InfiniteScrollGroupMessage from "./infinite-scroll-group-message";
import InfiniteScrollRemark from "./infinite-scroll-remark";
import * as LocalTimeHooks from "./local-time-hooks";
import Menu from "./dropdown-menu";
import TippyHook from "./tippy-hook";
import TrixEditor from "./trix";
import TrixContentPostHook from "./trix-content-post-hook";
import TrixContentReplyHook from "./trix-content-reply-hook";
import ScrollDown from "./scroll";

export default {
  ClearFlashHook,
  ColorSchemeHook,
  Flash,
  HoverGroupMessage,
  HoverRemark,
  InfiniteScrollGroupMessage,
  InfiniteScrollRemark,
  ...LocalTimeHooks,
  Menu,
  MossletFrameworkHooks,
  ScrollDown,
  TippyHook,
  TrixEditor,
  TrixContentPostHook,
  TrixContentReplyHook,
};
