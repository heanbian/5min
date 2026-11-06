/**
 * Copyright 2026 学记宝 / xuejibao.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const { t } = require('../../utils/i18n');

Page({
  data: {
    pageTitle: '',
    pageSub: '',
    icpLabel: '',
    icp: '',
    siteLabel: '',
    site: '',
  },

  onLoad() {
    this.setData({
      pageTitle: t('beianTitle'),
      pageSub: t('beianPageSub'),
      icpLabel: t('beianIcpLabel'),
      icp: t('beianIcp'),
      siteLabel: t('beianSiteLabel'),
      site: t('beianSite'),
    });
    wx.setNavigationBarTitle({ title: t('beianTitle') });
  },

  copyText(text) {
    if (!text) return;
    wx.setClipboardData({
      data: text,
      success() {
        wx.showToast({
          title: t('beianCopied'),
          icon: 'none',
        });
      },
    });
  },

  onCopyIcp() {
    this.copyText(this.data.icp);
  },

  onCopySite() {
    this.copyText(this.data.site);
  },
});
