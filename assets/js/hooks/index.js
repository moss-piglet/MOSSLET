import MossletFrameworkHooks from "../../_mosslet_framework/js/hooks";
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
import Menu from "./dropdown-menu";
import ModalPortal from "./modal-portal";
import TippyHook from "./tippy-hook";
import TrixEditor from "./trix";
import TrixContentPostHook from "./trix-content-post-hook";
import TrixContentReplyHook from "./trix-content-reply-hook";
import ScrollDown from "./scroll";

export default {
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
  Menu,
  ModalPortal,
  MossletFrameworkHooks,
  ScrollDown,
  TippyHook,
  TrixEditor,
  TrixContentPostHook,
  TrixContentReplyHook,
};
